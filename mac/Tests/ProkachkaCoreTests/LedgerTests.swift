import Foundation
import XCTest
@testable import ProkachkaCore

final class LedgerTests: XCTestCase {
    private let moscow = DayClock(timeZone: TimeZone(identifier: "Europe/Moscow")!)
    private var seq: Int64 = 0

    /// Дело с готовой оценкой: так тест не зависит от словаря.
    private func act(_ day: String, _ skill: Skill, _ xp: Int, device: String = "mac", steps: [Step] = [], id: String? = nil) -> Event {
        seq += 1
        let a = Assessment(skill: skill, xp: xp, steps: steps, sure: true)
        return Event.act("дело \(seq)", a, ts: 1_700_000_000_000 + seq * 1000, day: day, device: device, id: id ?? "a\(seq)")
    }

    func testDayStartsAtFourInTheMorning() {
        let f = ISO8601DateFormatter()
        XCTAssertEqual(moscow.key(f.date(from: "2026-11-01T00:30:00+03:00")!), "2026-10-31")
        XCTAssertEqual(moscow.key(f.date(from: "2026-11-01T04:00:00+03:00")!), "2026-11-01")
        XCTAssertEqual(DayClock.weekStart("2026-11-01"), "2026-10-26")
        XCTAssertEqual(DayClock.weekStart("2026-10-26"), "2026-10-26")
        XCTAssertEqual(DayClock.shift("2026-03-01", by: -1), "2026-02-28")
    }

    func testMinusNeverDropsBelowLevelStart() {
        let events = [act("2026-11-01", .work, 120), act("2026-11-01", .rest, -60)]
        let s = Ledger.snapshot(events, today: "2026-11-01", clock: moscow)
        XCTAssertEqual(s.level.level, 2)
        XCTAssertEqual(s.total, 100)
        XCTAssertEqual(s.skills[.rest]?.total, 0)
    }

    func testEditChangesEntryAndCalibration() {
        let a = act("2026-11-01", .work, 100)
        let events = [a, Event.edit(a.id, .up, ts: a.ts + 1, day: a.day, device: "mac")]
        let s = Ledger.snapshot(events, today: "2026-11-01", clock: moscow)
        XCTAssertEqual(s.entries.first?.xp, 125)
        XCTAssertEqual(s.entries.first?.steps.last, Step(name: "Твоя правка: мало", val: "×1,25"))
        XCTAssertEqual(s.calibration[.work], 1.1)
        XCTAssertEqual(s.context().calibration[.work], 1.1)
    }

    func testDeleteRemovesEntry() {
        let a = act("2026-11-01", .body, 50)
        let s = Ledger.snapshot([a, Event.delete(a.id, ts: a.ts + 1, day: a.day, device: "phone")], today: "2026-11-01", clock: moscow)
        XCTAssertTrue(s.entries.isEmpty)
        XCTAssertEqual(s.total, 0)
    }

    func testStreakCountsConsecutivePositiveDays() {
        let events = [act("2026-10-27", .body, 40), act("2026-10-29", .body, 40), act("2026-10-30", .mind, 30),
                      act("2026-10-31", .rest, -20), act("2026-10-31", .work, 45)]
        XCTAssertEqual(Ledger.snapshot(events, today: "2026-11-01", clock: moscow).streak, 3)
        let withToday = events + [act("2026-11-01", .home, 20)]
        XCTAssertEqual(Ledger.snapshot(withToday, today: "2026-11-01", clock: moscow).streak, 4)
        XCTAssertEqual(Ledger.snapshot(events + [act("2026-10-31", .rest, -10)], today: "2026-11-02", clock: moscow).streak, 0)
    }

    func testQuestRewardIsDueOnceAndHasStableId() {
        let today = "2026-11-01"
        var events = (0..<5).map { _ in act(today, .work, 45) }
        var s = Ledger.snapshot(events, today: today, clock: moscow)
        let due = s.dueQuestEvents(ts: 1, device: "mac")
        XCTAssertTrue(due.contains { $0.id == "q-day-five-2026-11-01" && $0.xp == 60 })
        // Без истории отстают Тело и Ум, их квесты ещё не выполнены.
        XCTAssertEqual(s.quests.prefix(2).map(\.skill), [.body, .mind])

        events += due
        s = Ledger.snapshot(events, today: today, clock: moscow)
        XCTAssertTrue(s.dueQuestEvents(ts: 2, device: "mac").isEmpty)
        // Второе устройство выполнило тот же квест офлайн: после слияния награда одна.
        let phoneDue = Event(id: "q-day-five-2026-11-01", kind: .quest, ts: 3, day: today, device: "phone", text: "Квест", skill: .quest, xp: 60, steps: [])
        let merged = Ledger.merge(events, [phoneDue])
        XCTAssertEqual(merged.filter { $0.kind == .quest && $0.id == "q-day-five-2026-11-01" }.count, 1)
    }

    func testMergeOrderDoesNotMatter() {
        let mac = [act("2026-10-31", .work, 45, device: "mac"), act("2026-11-01", .body, 60, device: "mac")]
        let phone = [act("2026-10-31", .people, 25, device: "phone"), act("2026-11-01", .rest, -20, device: "phone")]
        let a = Ledger.snapshot(Ledger.merge(mac, phone), today: "2026-11-01", clock: moscow)
        let b = Ledger.snapshot(Ledger.merge(phone, mac + phone), today: "2026-11-01", clock: moscow)
        XCTAssertEqual(a.entries, b.entries)
        XCTAssertEqual(a.total, b.total)
        XCTAssertEqual(a.coins, b.coins)
    }

    func testCoinsAreTenPercentMinusSpends() {
        let events = [act("2026-11-01", .work, 145), act("2026-11-01", .body, 62), act("2026-11-01", .rest, -20),
                      Event.spend("Кофе", cost: 15, ts: 9_999_999_999_999, day: "2026-11-01", device: "mac")]
        XCTAssertEqual(Ledger.snapshot(events, today: "2026-11-01", clock: moscow).coins, 20 - 15)
    }

    func testAchievementsFromHistory() {
        var events: [Event] = []
        for d in 1...7 { events.append(act(String(format: "2026-10-%02d", d), .mind, 50, steps: [Step(name: "Сам", val: "×1,5")])) }
        let s = Ledger.snapshot(events, today: "2026-10-07", clock: moscow)
        let byId = Dictionary(uniqueKeysWithValues: s.achievements.map { ($0.id, $0) })
        XCTAssertEqual(byId["streak7"]?.done, true)
        XCTAssertEqual(byId["clean7"]?.done, true)
        XCTAssertEqual(byId["self10"]?.progress, 7)
        XCTAssertEqual(byId["xp300"]?.done, false)
    }

    func testAssessedActRoundTripsThroughJSON() throws {
        let a = try XCTUnwrap(Assessor.assess("Сам написал алгоритм за 2 часа", AssessContext()))
        let e = Event.act("Сам написал алгоритм за 2 часа", a, ts: 1, day: "2026-11-01", device: "mac")
        let back = try JSONDecoder().decode(Event.self, from: JSONEncoder().encode(e))
        XCTAssertEqual(back, e)
        XCTAssertEqual(a.xp, 145)
    }
}
