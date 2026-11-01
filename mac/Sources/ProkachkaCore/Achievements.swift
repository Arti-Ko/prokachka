import Foundation

/// Описание достижения из каталога (spec/reference/achievements.mjs).
public struct AchievementDef: Sendable {
    public let id: String
    public let group: String
    public let metric: String
    public let goal: Int
    /// 1 бронза, 2 серебро, 3 золото, 4 платина.
    public let tier: Int
    public let title: String
    public let text: String
    /// Название скрыто, пока достижение не получено.
    public let hidden: Bool
}

public struct AchievementState: Identifiable, Equatable, Sendable {
    public let id: String
    public let group: String
    public let metric: String
    public let tier: Int
    public let title: String
    public let text: String
    public let hidden: Bool
    public let progress: Int
    public let goal: Int

    public var done: Bool { progress >= goal }
}

enum Achievements {
    static func states(_ metrics: [String: Int]) -> [AchievementState] {
        AchievementCatalog.all.map { d in
            AchievementState(id: d.id, group: d.group, metric: d.metric, tier: d.tier, title: d.title, text: d.text, hidden: d.hidden,
                             progress: min(metrics[d.metric] ?? 0, d.goal), goal: d.goal)
        }
    }

    /// Счётчики, на которые ссылается каталог. Имена совпадают с Kotlin-версией.
    static func metrics(entries: [Entry], total: Int, level: Int, skills: [Skill: SkillState], dayTotals: [String: Int],
                        positiveDays: Set<String>, edits: Int, spends: [Event], clock: DayClock) -> [String: Int] {
        let acts = entries.filter { !$0.isQuest }
        let plus = acts.filter { $0.xp > 0 }
        let minusDays = Set(acts.filter { $0.xp < 0 }.map(\.day))
        func steps(_ name: String) -> Int { acts.filter { $0.steps.contains { $0.name == name } }.count }

        var km = 0.0, pages = 0.0, focus = 0.0
        for e in plus where [.body, .mind, .work, .craft].contains(e.skill) {
            let q = Quantities(Assessor.prepare(e.text))
            if e.skill == .body { km += q.km ?? 0 }
            if e.skill == .mind { pages += q.pages ?? 0 }
            if e.skill != .body { focus += q.minutes ?? 0 }
        }
        var skillsPerDay: [String: Set<Skill>] = [:]
        for e in plus where Skill.trained.contains(e.skill) { skillsPerDay[e.day, default: []].insert(e.skill) }
        let weekends = positiveDays.filter { DayClock.weekday($0) == 7 && positiveDays.contains(DayClock.shift($0, by: 1)) }.count

        var m: [String: Int] = [
            "level": level,
            "xpTotal": total,
            "streakBest": Ledger.bestRun(positiveDays),
            "daysActive": positiveDays.count,
            "cleanBest": Ledger.bestRun(Set(acts.map(\.day)).subtracting(minusDays)),
            "comebacks": steps("С возвращением"),
            "weekends": weekends,
            "acts": plus.count,
            "xpDayBest": dayTotals.values.max() ?? 0,
            "bigAct": plus.map(\.xp).max() ?? 0,
            "skillsInDayBest": skillsPerDay.values.map(\.count).max() ?? 0,
            "km": Int(km.rounded(.down)),
            "pages": Int(pages),
            "focusMinutes": Int(focus),
            "selfMade": steps("Сам"),
            "hard": acts.filter { $0.steps.contains { $0.name == "Сложно" || $0.name == "Рекорд" } }.count,
            "records": steps("Рекорд"),
            "abstains": steps("Удержался"),
            "minuses": acts.filter { $0.xp < 0 }.count,
            "disputes": edits,
            "early": plus.filter { (4..<8).contains(clock.hour(ms: $0.ts)) }.count,
            "night": plus.filter { (0..<4).contains(clock.hour(ms: $0.ts)) }.count,
            "questsDone": entries.filter(\.isQuest).count,
            "rewardsTaken": spends.count,
            "spentTotal": spends.reduce(0) { $0 + ($1.cost ?? 0) },
        ]
        for s in Skill.trained {
            m["skillActs.\(s.rawValue)"] = plus.filter { $0.skill == s }.count
            m["skillLevel.\(s.rawValue)"] = skills[s]?.info.level ?? 1
        }
        return m
    }
}
