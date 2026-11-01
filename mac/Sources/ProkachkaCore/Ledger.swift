import Foundation

/// Дело или награда за квест после применения правок и удалений.
public struct Entry: Identifiable, Equatable, Sendable {
    public let id: String
    public let isQuest: Bool
    public let text: String
    public let skill: Skill
    public let xp: Int
    public let steps: [Step]
    public let ts: Int64
    public let day: String
    public let device: String
    public let edited: Bool
}

public struct SkillState: Equatable, Sendable {
    public let total: Int
    public let info: LevelInfo

    public init(total: Int) {
        self.total = total
        info = Levels.skill(total)
    }
}

/// Всё, что показывает интерфейс, выведено из журнала одной функцией.
public struct Snapshot: Sendable {
    public let today: String
    /// Дела и квесты в хронологическом порядке.
    public let entries: [Entry]
    public let total: Int
    public let level: LevelInfo
    public let skills: [Skill: SkillState]
    public let calibration: [Skill: Double]
    public let coins: Int
    public let spends: [Event]
    public let streak: Int
    public let dayTotals: [String: Int]
    public let quests: [QuestState]
    public let achievements: [AchievementState]
    /// Счётчики для достижений: «acts», «km», «skillActs.body»…
    public let metrics: [String: Int]

    public var rank: String { Levels.rank(level.level) }
    public var todayEntries: [Entry] { entries.filter { $0.day == today }.reversed() }
    public var todayXP: Int { dayTotals[today] ?? 0 }

    /// Контекст для оценки следующего дела.
    public func context(override: Skill? = nil) -> AssessContext {
        let acts = entries.filter { $0.day == today && !$0.isQuest }
            .map { DayAct(skill: $0.skill, xp: $0.xp, text: Assessor.prepare($0.text), label: $0.steps.first?.name ?? "") }
        var lastTrained: [Skill: Int] = [:]
        var lastAny: String?
        for e in entries where !e.isQuest && e.xp > 0 && e.day < today {
            if lastAny.map({ e.day > $0 }) ?? true { lastAny = e.day }
            let ago = DayClock.daysBetween(e.day, today)
            if Skill.trained.contains(e.skill) { lastTrained[e.skill] = min(lastTrained[e.skill] ?? .max, ago) }
        }
        return AssessContext(dayActs: acts, streak: streak, calibration: calibration, lastTrained: lastTrained,
                             daysSinceAny: lastAny.map { DayClock.daysBetween($0, today) }, override: override)
    }

    /// Награды за квесты, которые выполнены, но ещё не записаны в журнал.
    public func dueQuestEvents(ts: Int64, device: String) -> [Event] {
        quests.filter { $0.progress >= $0.goal && !$0.rewarded }.map {
            Event(id: $0.id, kind: .quest, ts: ts, day: today, device: device, text: "Квест «\($0.title)»", skill: .quest,
                  xp: $0.xp, steps: [Step(name: "Награда за квест", val: "+\($0.xp)")])
        }
    }
}

public enum Ledger {
    public static func snapshot(_ events: [Event], today: String, clock: DayClock = DayClock()) -> Snapshot {
        let log = dedupe(events).sorted(by: Event.chronological)

        var deleted = Set<String>()
        var edits: [String: [Event.Tune]] = [:]
        var calibration: [Skill: Double] = [:]
        var spends: [Event] = []
        var targets: [String: Skill] = [:]
        for e in log where e.kind == .act { targets[e.id] = e.skill }
        for e in log {
            switch e.kind {
            case .delete: if let t = e.target { deleted.insert(t) }
            case .edit:
                guard let t = e.target, let tune = e.tune else { continue }
                edits[t, default: []].append(tune)
                if let k = tune.calibration, let skill = targets[t] {
                    calibration[skill] = Fmt.jsRound((calibration[skill] ?? 1) * k * 100) / 100
                }
            case .spend: spends.append(e)
            case .act, .quest: break
            }
        }

        let entries: [Entry] = log.compactMap { e in
            guard e.kind == .act || e.kind == .quest, !deleted.contains(e.id), let skill = e.skill, let base = e.xp else { return nil }
            var xp = Double(base)
            var steps = e.steps ?? []
            for tune in edits[e.id] ?? [] {
                xp = Fmt.jsRound(xp * tune.factor)
                steps.append(Step(name: tune.label, val: "×\(Fmt.k(tune.factor))"))
            }
            return Entry(id: e.id, isQuest: e.kind == .quest, text: e.text ?? "", skill: skill, xp: Int(xp), steps: steps,
                         ts: e.ts, day: e.day, device: e.device, edited: edits[e.id] != nil)
        }

        // Уровень не теряется: минус не опускает ниже начала текущего уровня.
        let total = entries.reduce(0) { t, e in max(t + e.xp, Levels.info(t).start) }
        var skillTotals: [Skill: Int] = [:]
        for e in entries where Skill.trained.contains(e.skill) { skillTotals[e.skill, default: 0] += e.xp }
        let skills = Dictionary(uniqueKeysWithValues: Skill.trained.map { s -> (Skill, SkillState) in
            let t = max(0, skillTotals[s] ?? 0)
            return (s, SkillState(total: t))
        })

        var dayTotals: [String: Int] = [:]
        for e in entries { dayTotals[e.day, default: 0] += e.xp }
        let earned = entries.filter { $0.xp > 0 }.reduce(0) { $0 + $1.xp }
        let coins = earned / 10 - spends.reduce(0) { $0 + ($1.cost ?? 0) }

        let positiveDays = Set(entries.filter { !$0.isQuest && $0.xp > 0 }.map(\.day))
        var streak = positiveDays.contains(today) ? 1 : 0
        var cursor = DayClock.shift(today, by: -1)
        while positiveDays.contains(cursor) {
            streak += 1
            cursor = DayClock.shift(cursor, by: -1)
        }

        let quests = Quests.states(entries: entries, today: today, rewarded: Set(log.filter { $0.kind == .quest }.map(\.id)))
        let level = Levels.info(total)
        let metrics = Achievements.metrics(entries: entries, total: total, level: level.level, skills: skills, dayTotals: dayTotals,
                                           positiveDays: positiveDays, edits: log.filter { $0.kind == .edit }.count, spends: spends, clock: clock)
        return Snapshot(today: today, entries: entries, total: total, level: level, skills: skills, calibration: calibration,
                        coins: coins, spends: spends, streak: streak, dayTotals: dayTotals, quests: quests,
                        achievements: Achievements.states(metrics), metrics: metrics)
    }

    /// Объединение журналов: одинаковый `id` — одна запись.
    public static func merge(_ a: [Event], _ b: [Event]) -> [Event] { dedupe(a + b).sorted(by: Event.chronological) }

    static func dedupe(_ events: [Event]) -> [Event] {
        var seen = Set<String>()
        return events.filter { seen.insert($0.id).inserted }
    }

    /// Самая длинная серия подряд идущих дней из множества.
    static func bestRun(_ days: Set<String>) -> Int {
        var best = 0
        for d in days where !days.contains(DayClock.shift(d, by: -1)) {
            var run = 1, cursor = DayClock.shift(d, by: 1)
            while days.contains(cursor) {
                run += 1
                cursor = DayClock.shift(cursor, by: 1)
            }
            best = max(best, run)
        }
        return best
    }
}
