import Foundation

public struct AchievementState: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let text: String
    public let progress: Int
    public let goal: Int

    public var done: Bool { progress >= goal }
}

enum Achievements {
    static func states(entries: [Entry], level: Int, dayTotals: [String: Int], positiveDays: Set<String>, clock: DayClock) -> [AchievementState] {
        let acts = entries.filter { !$0.isQuest }
        let actDays = Set(acts.map(\.day))
        let minusDays = Set(acts.filter { $0.xp < 0 }.map(\.day))
        let early = acts.filter { $0.xp > 0 && (4..<8).contains(clock.hour(ms: $0.ts)) }.count
        let selfMade = acts.filter { $0.steps.contains { $0.name == "Сам" } }.count

        func a(_ id: String, _ title: String, _ text: String, _ progress: Int, _ goal: Int) -> AchievementState {
            AchievementState(id: id, title: title, text: text, progress: min(progress, goal), goal: goal)
        }
        return [
            a("first", "Первое дело", "Записать первое дело", acts.count, 1),
            a("lvl10", "Двузначный", "Дойти до 10 уровня", level, 10),
            a("streak7", "Неделя подряд", "7 дней без пропусков", Ledger.bestRun(positiveDays), 7),
            a("xp300", "Три сотни", "300 XP за один день", dayTotals.values.max() ?? 0, 300),
            a("self10", "Сам себе сеньор", "10 дел с пометкой «сам»", selfMade, 10),
            a("early5", "Ранняя пташка", "5 дел до 8 утра", early, 5),
            a("mind20", "Книжный червь", "20 дел для «Ума»", acts.filter { $0.skill == .mind && $0.xp > 0 }.count, 20),
            a("clean7", "Чистая неделя", "7 дней подряд без минусов", Ledger.bestRun(actDays.subtracting(minusDays)), 7),
            a("lvl15", "Мастер", "Дойти до 15 уровня", level, 15),
            a("streak30", "Месяц подряд", "30 дней без пропусков", Ledger.bestRun(positiveDays), 30),
        ]
    }
}
