import Foundation
import XCTest
@testable import ProkachkaCore

/// Общая для Swift и Kotlin проверка журнала: история за три недели → итоги в spec/vectors/ledger.json.
/// Пересоздать файл: UPDATE_SPEC=1 swift test --filter GoldenLedgerTests. Kotlin читает тот же файл.
final class GoldenLedgerTests: XCTestCase {
    private struct Expect: Codable, Equatable {
        struct Quest: Codable, Equatable { let id: String; let progress: Int; let rewarded: Bool }
        let total: Int
        let level: Int
        let streak: Int
        let coins: Int
        let todayXP: Int
        let calibration: [String: Double]
        let quests: [Quest]
        let metrics: [String: Int]
        let achievementsDone: [String]
    }

    private struct Golden: Codable {
        let today: String
        let zone: String
        let events: [Event]
        let expect: Expect
    }

    private static let file = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("spec/vectors/ledger.json")

    private static let script: [[String]] = [
        ["Пробежал 5 км", "Сам написал алгоритм за 2 часа", "Позвонил маме"],
        ["Прочитал 30 страниц", "Залип в тиктоке 2 часа"],
        ["Тренировка до отказа", "Приготовил ужин", "Медитировал 15 минут", "Закрыл 3 задачи"],
        [],
        ["Проспал до обеда", "Не пошёл в зал"],
        [],
        [],
        ["Вернулся: гулял 6 км пешком", "Нарисовал скетч", "Выучил 40 слов английского"],
        ["Сделал 3 подхода по 20 раз", "Работал весь вечер", "Работал весь вечер", "Полил цветы", "Созвонился с мамой"],
        ["Поставил личный рекорд в жиме", "Курил", "Курил"],
        ["Не курил весь день", "Прочитал 2 главы", "Смонтировал видео 4 часа"],
        ["Проехал 20 км на велосипеде", "Сыграл в шахматы", "Убрался в квартире весь день", "Сам разобрался с BPMN-диаграммой", "Помог другу с переездом"],
        ["1ч30м занимался английским", "Посмотрел на закат"],
        ["Пробежал пять километров", "Читал два часа", "Написал пост", "Спал 8 часов", "Отказался от сладкого", "Решил 3 задачи на литкоде"],
        ["Пробежал 5 км", "Пробежал 5 км", "Сделал ТЗ по туториалу"],
        ["Отправил отчёт клиенту, 3 часа", "Сходил в сауну"],
        ["Поужинал с семьёй", "Прошёл 12000 шагов"],
        ["Опоздал на встречу", "Наконец сдал экзамен", "Йога 45 мин"],
        ["Двадцать пять отжиманий", "Нарисовал скетч", "Помыл посуду быстро", "Позвонил маме", "Медитировал пол часа", "Написал ТЗ на экран профиля, 1,5 часа"],
        ["Прокрастинировал", "Сам написал алгоритм за 2 часа"],
        ["Пробежал 2,5 км за 20 минут", "Прочёл книгу за 3 часа", "Проплыл 800 м в бассейне"],
    ]

    /// Проигрывает сценарий как настоящий пользователь: каждое дело оценивается по текущему снимку.
    private func buildEvents(clock: DayClock, today: String) -> [Event] {
        var events: [Event] = []
        let start = DayClock.shift(today, by: -(Self.script.count - 1))
        var ts: Int64 = 1_790_000_000_000
        for (i, texts) in Self.script.enumerated() {
            let day = DayClock.shift(start, by: i)
            for (j, text) in texts.enumerated() {
                ts += 3_600_000
                let device = (i + j) % 2 == 0 ? "mac-golden" : "phone-golden"
                let snap = Ledger.snapshot(events, today: day, clock: clock)
                let override: Skill? = text == "Посмотрел на закат" ? .rest : nil
                guard let a = Assessor.assess(text, snap.context(override: override)) else { continue }
                let act = Event.act(text, a, ts: ts, day: day, device: device, id: String(format: "g%02d-%d", i, j))
                events.append(act)
                events += Ledger.snapshot(events, today: day, clock: clock).dueQuestEvents(ts: ts + 1, device: device)
            }
            if i == 9 { events.append(Event(id: "g-edit-1", kind: .edit, ts: ts + 10, day: day, device: "phone-golden", target: "g09-0", tune: .up)) }
            if i == 11 { events.append(Event(id: "g-edit-2", kind: .edit, ts: ts + 10, day: day, device: "mac-golden", target: "g11-1", tune: .down)) }
            if i == 12 { events.append(Event(id: "g-del-1", kind: .delete, ts: ts + 10, day: day, device: "mac-golden", target: "g12-1")) }
            if i == 14 { events.append(Event(id: "g-soft-1", kind: .edit, ts: ts + 10, day: day, device: "phone-golden", target: "g09-2", tune: .soft)) }
            if i == 16 { events.append(Event(id: "g-spend-1", kind: .spend, ts: ts + 10, day: day, device: "phone-golden", text: "Кофе", cost: 60)) }
        }
        return events
    }

    private func expect(_ s: Snapshot) -> Expect {
        Expect(total: s.total, level: s.level.level, streak: s.streak, coins: s.coins, todayXP: s.todayXP,
               calibration: Dictionary(uniqueKeysWithValues: s.calibration.map { ($0.key.rawValue, $0.value) }),
               quests: s.quests.map { .init(id: $0.id, progress: $0.progress, rewarded: $0.rewarded) },
               metrics: s.metrics, achievementsDone: s.achievements.filter(\.done).map(\.id))
    }

    func testLedgerGolden() throws {
        let zone = "Europe/Moscow", today = "2026-11-01"
        let clock = DayClock(timeZone: TimeZone(identifier: zone)!)
        if ProcessInfo.processInfo.environment["UPDATE_SPEC"] == "1" {
            let events = buildEvents(clock: clock, today: today)
            let golden = Golden(today: today, zone: zone, events: events, expect: expect(Ledger.snapshot(events, today: today, clock: clock)))
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try enc.encode(golden).write(to: Self.file)
        }
        let golden = try JSONDecoder().decode(Golden.self, from: Data(contentsOf: Self.file))
        XCTAssertGreaterThan(golden.events.count, 50)
        XCTAssertEqual(expect(Ledger.snapshot(golden.events, today: golden.today, clock: clock)), golden.expect)
    }
}
