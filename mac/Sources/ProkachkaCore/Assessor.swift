import Foundation

/// Одна строка разбора оценки: «Сам» → «×1,5».
public struct Step: Codable, Equatable, Hashable, Sendable {
    public let name: String
    public let val: String

    public init(name: String, val: String) {
        self.name = name
        self.val = val
    }
}

public struct Assessment: Equatable, Sendable {
    public let skill: Skill
    public let xp: Int
    public let steps: [Step]
    /// false — навык не распознан, интерфейс должен предложить выбрать его.
    public let sure: Bool
}

/// Дело, уже записанное в этот день: нужно для повторов и бонуса за первое дело.
public struct DayAct: Equatable, Sendable {
    public let skill: Skill
    public let xp: Int

    public init(skill: Skill, xp: Int) {
        self.skill = skill
        self.xp = xp
    }
}

public struct AssessContext: Sendable {
    public var dayActs: [DayAct]
    public var streak: Int
    public var calibration: [Skill: Double]
    /// Навык, выбранный вручную, когда текст не распознан.
    public var override: Skill?

    public init(dayActs: [DayAct] = [], streak: Int = 0, calibration: [Skill: Double] = [:], override: Skill? = nil) {
        self.dayActs = dayActs
        self.streak = streak
        self.calibration = calibration
        self.override = override
    }
}

/// Формула: База × Объём × Сам/с помощью × Сложность × Стрик × Повтор × Калибровка + Бонусы.
public enum Assessor {
    /// Пробелы, цифры и знаки не считаются: «12» или «ok» — это ещё не дело.
    private static let ignoredForLength = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "0123456789.,!?-"))

    public static func normalize(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "ё", with: "е")
    }

    public static func assess(_ raw: String, _ ctx: AssessContext) -> Assessment? {
        let t = normalize(raw)
        guard t.unicodeScalars.filter({ !ignoredForLength.contains($0) }).count >= 3 else { return nil }

        var steps: [Step] = []
        let q = Quantities(t)
        let abstain = Rules.abstain.test(t)

        if !abstain, let minus = Rules.minuses.first(where: { $0.rx.test(t) }) {
            var xp = minus.xp
            steps.append(Step(name: minus.label, val: Fmt.signed(minus.xp)))
            if minus.perHour {
                let h = clamp((q.minutes ?? 60) / 60, 0.5, 6)
                xp = Fmt.jsRound(xp * h)
                steps.append(Step(name: "Время · \(Fmt.duration(minutes: h * 60))", val: "×\(Fmt.k(h))"))
            }
            return Assessment(skill: minus.skill, xp: Int(xp), steps: steps, sure: true)
        }

        let skill: Skill
        var xp: Double
        if abstain {
            skill = .rest
            xp = 20
            steps.append(Step(name: "Удержался", val: "20"))
        } else {
            skill = ctx.override ?? detectSkill(t)
            xp = skill.base
            steps.append(Step(name: "База · \(skill.title)", val: Fmt.plain(xp)))
        }

        func mul(_ name: String, _ k: Double) {
            xp *= k
            steps.append(Step(name: name, val: "×\(Fmt.k(k))"))
        }

        if !abstain {
            if let e = q.effort { mul("Объём · \(e.label)", e.k) }
            if Rules.selfMade.test(t) { mul("Сам", 1.5) } else if Rules.helped.test(t) { mul("С помощью", 0.8) }
            if Rules.hard.test(t) { mul("Сложно", 1.3) } else if Rules.easy.test(t) { mul("Легко", 0.7) }
        }
        if ctx.streak > 0 { mul("Стрик · \(Fmt.days(ctx.streak))", 1 + Double(min(ctx.streak, 10)) * 0.03) }
        let repeats = ctx.dayActs.filter { $0.skill == skill && $0.xp > 0 }.count
        if repeats > 0 { mul("Повтор · \(repeats + 1)-й раз за день", pow(0.85, Double(repeats))) }
        let cal = ctx.calibration[skill] ?? 1
        if abs(cal - 1) > 0.001 { mul("Твоя калибровка", cal) }

        xp = Fmt.jsRound(xp)
        if !ctx.dayActs.contains(where: { $0.xp > 0 }) {
            xp += 10
            steps.append(Step(name: "Первое дело за день", val: "+10"))
        }
        return Assessment(skill: skill, xp: Int(xp), steps: steps, sure: skill != .misc)
    }

    static func detectSkill(_ t: String) -> Skill {
        var score: [Skill: Int] = [:]
        for (skill, weight, rx) in Rules.cues where rx.test(t) { score[skill, default: 0] += weight }
        var best = Skill.misc, top = 0
        for s in Skill.trained where (score[s] ?? 0) > top {
            best = s
            top = score[s]!
        }
        return best
    }
}

func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, v)) }

/// Числа из текста: минуты, километры, страницы, повторы, задачи, слова.
struct Quantities {
    var minutes: Double?
    var km: Double?
    var pages: Double?
    var reps: Double?
    var tasks: Double?
    var words: Double?

    private static let hoursMinutes = Rx("(\\d+(?:[.,]\\d+)?)\\s*(?:ч|час)[а-я]*\\s*(\\d+)\\s*мин")
    private static let hours = Rx("(\\d+(?:[.,]\\d+)?)\\s*(?:ч(?![а-я])|час)")
    private static let mins = Rx("(\\d+)\\s*мин")
    private static let hourWord = Rx("(?<![а-я])час(?![а-я])")
    private static let kmRx = Rx("(\\d+(?:[.,]\\d+)?)\\s*(?:км|килом)")
    private static let pagesRx = Rx("(\\d+)\\s*стр")
    private static let repsRx = Rx("(\\d+)\\s*(?:раз(?![а-я])|отжим|подтяг|присед)")
    private static let tasksRx = Rx("(\\d+)\\s*задач")
    private static let wordsRx = Rx("(\\d+)\\s*слов")

    init(_ t: String) {
        func n(_ s: String?) -> Double { Double((s ?? "0").replacingOccurrences(of: ",", with: ".")) ?? 0 }
        if let g = Self.hoursMinutes.groups(t) { minutes = n(g[1]) * 60 + n(g[2]) }
        else if let g = Self.hours.groups(t) { minutes = n(g[1]) * 60 }
        else if let g = Self.mins.groups(t) { minutes = n(g[1]) }
        else if t.contains("полтора час") { minutes = 90 }
        else if t.contains("полчаса") { minutes = 30 }
        else if t.contains("весь день") || t.contains("целый день") { minutes = 300 }
        else if Self.hourWord.test(t) { minutes = 60 }
        if let g = Self.kmRx.groups(t) { km = n(g[1]) }
        if let g = Self.pagesRx.groups(t) { pages = n(g[1]) }
        if let g = Self.repsRx.groups(t) { reps = n(g[1]) }
        if let g = Self.tasksRx.groups(t) { tasks = n(g[1]) }
        if let g = Self.wordsRx.groups(t) { words = n(g[1]) }
    }

    /// Первая найденная мера по порядку из эталона. Объём идёт под корнем, от ×0,5 до ×3.
    var effort: (k: Double, label: String)? {
        let norms: [(Double?, Double, (Double) -> String)] = [
            (km, 3, { "\(Fmt.k($0)) км" }),
            (pages, 20, { "\(Fmt.plain($0)) стр." }),
            (reps, 30, { "\(Fmt.plain($0)) повт." }),
            (tasks, 2, { v in "\(Fmt.plain(v)) \(Fmt.plural(Int(v), "задача", "задачи", "задач"))" }),
            (words, 20, { "\(Fmt.plain($0)) слов" }),
            (minutes, 30, { Fmt.duration(minutes: $0) }),
        ]
        for (value, norm, label) in norms {
            if let v = value { return (clamp((v / norm).squareRoot(), 0.5, 3), label(v)) }
        }
        return nil
    }
}
