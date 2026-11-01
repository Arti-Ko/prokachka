import Foundation

public struct QuestState: Identifiable, Equatable, Sendable {
    public enum Period: String, Sendable { case day, week }

    /// Он же id события-награды: «q-day-body-2026-11-01». Одинаков на всех устройствах.
    public let id: String
    public let period: Period
    public let title: String
    public let skill: Skill?
    public let goal: Int
    public let progress: Int
    public let xp: Int
    /// Награда уже в журнале.
    public let rewarded: Bool

    public var done: Bool { rewarded || progress >= goal }
}

/// Квесты подбираются под два самых отстающих навыка. Отставание считается по журналу
/// до начала дня или недели, поэтому набор не меняется в течение дня и совпадает на устройствах.
enum Quests {
    private static let daily: [Skill: String] = [
        .body: "Подвигаться", .mind: "Узнать новое", .work: "Довести дело до конца", .home: "Навести порядок",
        .people: "Связаться с близкими", .craft: "Создать что-нибудь", .rest: "Позаботиться о режиме",
    ]

    static func states(entries: [Entry], today: String, rewarded: Set<String>) -> [QuestState] {
        let weekStart = DayClock.weekStart(today)
        let acts = entries.filter { !$0.isQuest && $0.xp > 0 }
        let todayActs = acts.filter { $0.day == today }
        let weekActs = acts.filter { $0.day >= weekStart && $0.day <= today }
        let dayWeak = weakest(entries.filter { $0.day < today })
        let weekWeak = weakest(entries.filter { $0.day < weekStart })

        func make(_ key: String, _ period: QuestState.Period, _ title: String, _ skill: Skill?, _ goal: Int, _ xp: Int, _ pool: [Entry]) -> QuestState {
            let id = "q-\(period.rawValue)-\(key)-\(period == .day ? today : weekStart)"
            let progress = min(goal, pool.filter { skill == nil || $0.skill == skill }.count)
            return QuestState(id: id, period: period, title: title, skill: skill, goal: goal, progress: progress, xp: xp, rewarded: rewarded.contains(id))
        }

        return dayWeak.prefix(2).map { make($0.rawValue, .day, daily[$0]!, $0, 1, 40, todayActs) }
            + [make("five", .day, "Пять дел за день", nil, 5, 60, todayActs),
               make(weekWeak[0].rawValue, .week, "Четыре раза «\(weekWeak[0].title)»", weekWeak[0], 4, 120, weekActs),
               make("twenty", .week, "Двадцать дел за неделю", nil, 20, 150, weekActs)]
    }

    /// Навыки от самого отстающего; при равенстве — в порядке Skill.trained.
    static func weakest(_ entries: [Entry]) -> [Skill] {
        var totals: [Skill: Int] = [:]
        for e in entries { totals[e.skill, default: 0] += e.xp }
        return Skill.trained.enumerated()
            .sorted { (totals[$0.element] ?? 0, $0.offset) < (totals[$1.element] ?? 0, $1.offset) }
            .map(\.element)
    }
}
