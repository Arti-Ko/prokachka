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

/// Дело, уже записанное в этот день.
public struct DayAct: Equatable, Sendable {
    public let skill: Skill
    public let xp: Int
    /// Текст после `Assessor.prepare` — для «повтора того же».
    public let text: String
    /// Первая строка разбора — для «снова тот же минус».
    public let label: String

    public init(skill: Skill, xp: Int, text: String = "", label: String = "") {
        self.skill = skill
        self.xp = xp
        self.text = text
        self.label = label
    }
}

public struct AssessContext: Sendable {
    public var dayActs: [DayAct]
    /// Дни подряд, считая сегодня, если сегодня уже был плюс.
    public var streak: Int
    public var calibration: [Skill: Double]
    /// Сколько дней назад навык качался последний раз (только дни до сегодняшнего).
    public var lastTrained: [Skill: Int]
    /// Сколько дней назад был последний день с плюсом; nil — истории нет.
    public var daysSinceAny: Int?
    /// Навык, выбранный вручную, когда текст не распознан.
    public var override: Skill?

    public init(dayActs: [DayAct] = [], streak: Int = 0, calibration: [Skill: Double] = [:], lastTrained: [Skill: Int] = [:],
                daysSinceAny: Int? = nil, override: Skill? = nil) {
        self.dayActs = dayActs
        self.streak = streak
        self.calibration = calibration
        self.lastTrained = lastTrained
        self.daysSinceAny = daysSinceAny
        self.override = override
    }
}

/// Почему текст не оценён.
public enum AssessHint: String, Sendable {
    /// Мало слов: «ok», «12».
    case short
    /// Это намерение, а не дело: «завтра пойду в зал».
    case plan
}

/// Формула (spec/reference/engine.mjs): База × Объём × Сам/с помощью × Рекорд/сложность × Интенсивность
/// × Стрик × Разнообразие × Повтор × Калибровка × Усталость + Бонусы.
public enum Assessor {
    /// Пробелы, цифры и знаки не считаются: «12» или «ok» — это ещё не дело.
    private static let ignoredForLength = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "0123456789.,!?-"))
    private static let word = Rx("[а-я]+")
    private static let tensUnits = Rx("(?<![\\d.,])([2-9]0) ([1-9])(?![\\d.,])")
    private static let hundreds = Rx("(?<![\\d.,])([1-9]00) ([1-9]\\d?)(?![\\d.,])")
    private static let half = Rx("(?<![а-я])пол (?=час|км|литр|стакан)")

    /// Нижний регистр, ё → е, числа словами → цифры.
    public static func prepare(_ raw: String) -> String {
        var t = raw.lowercased().replacingOccurrences(of: "ё", with: "е")
        t = word.replace(t) { g in Rules.numberWords[g[0]!].map(Fmt.plain) ?? g[0]! }
        t = tensUnits.replace(t) { g in String(Int(g[1]!)! + Int(g[2]!)!) }
        t = hundreds.replace(t) { g in String(Int(g[1]!)! + Int(g[2]!)!) }
        t = half.replace(t) { _ in "0.5 " }
        return t
    }

    private static func meaningful(_ t: String) -> Int { t.unicodeScalars.filter { !ignoredForLength.contains($0) }.count }
    private static func isPlan(_ t: String) -> Bool { Rules.plan.test(t) && !Rules.past.test(t) }

    public static func hint(_ raw: String) -> AssessHint? {
        let t = prepare(raw)
        if t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
        if meaningful(t) < 3 { return .short }
        return isPlan(t) ? .plan : nil
    }

    /// Множитель стрика: +3% за день до 10 дней, дальше +1% до +50% на 30-й день.
    static func streakK(_ s: Int) -> Double {
        1 + Double(min(s, 10)) * 0.03 + Double(max(0, min(s, 30) - 10)) * 0.01
    }

    public static func assess(_ raw: String, _ ctx: AssessContext) -> Assessment? {
        let t = prepare(raw)
        guard meaningful(t) >= 3, !isPlan(t) else { return nil }
        var steps: [Step] = []
        let q = Quantities(t)
        let positiveToday = ctx.dayActs.filter { $0.xp > 0 }
        let abstain = Rules.abstain.test(t)

        if !abstain, let m = minusRule(t) {
            var xp = m.xp
            steps.append(Step(name: m.label, val: Fmt.signed(m.xp)))
            if m.perHour {
                let h = clamp((q.minutes ?? 60) / 60, 0.5, 6)
                xp *= h
                steps.append(Step(name: "Время · \(Fmt.duration(minutes: h * 60))", val: "×\(Fmt.k(h))"))
            }
            let again = ctx.dayActs.filter { $0.xp < 0 && $0.label == m.label }.count
            if again > 0 {
                let k = min(2, 1 + 0.5 * Double(again))
                xp *= k
                steps.append(Step(name: "Снова · \(again + 1)-й раз за день", val: "×\(Fmt.k(k))"))
            }
            return Assessment(skill: m.skill, xp: Int(Fmt.jsRound(xp)), steps: steps, sure: true)
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
            if let e = q.effort(skill: skill, text: t) { mul("Объём · \(e.label)", e.k) }
            if Rules.selfMade.test(t) { mul("Сам", 1.5) } else if Rules.helped.test(t) { mul("С помощью", 0.8) }
            if Rules.record.test(t) { mul("Рекорд", 1.5) } else if Rules.hard.test(t) { mul("Сложно", 1.3) } else if Rules.easy.test(t) { mul("Легко", 0.7) }
            if Rules.intense.test(t) { mul("Интенсивно", 1.2) }
        }
        if ctx.streak > 0 { mul("Стрик · \(Fmt.days(ctx.streak))", streakK(ctx.streak)) }
        if !abstain && Skill.trained.contains(skill) && !positiveToday.contains(where: { $0.skill == skill }) {
            if let ago = ctx.lastTrained[skill] {
                if ago >= 3 { mul("Давно не качал · \(Fmt.days(ago))", 1.2) }
            } else {
                mul("Новый навык", 1.2)
            }
        }
        let same = positiveToday.filter { $0.text == t }.count
        let repeats = positiveToday.filter { $0.skill == skill }.count
        if same > 0 { mul("Повтор того же · \(same + 1)-й раз", pow(0.5, Double(same))) }
        else if repeats > 0 { mul("Повтор · \(repeats + 1)-й раз за день", pow(0.85, Double(repeats))) }
        let cal = ctx.calibration[skill] ?? 1
        if abs(cal - 1) > 0.001 { mul("Твоя калибровка", cal) }
        let dayXP = positiveToday.reduce(0) { $0 + $1.xp }
        if dayXP >= 800 { mul("Усталость дня · больше 800 XP", 0.5) }
        else if dayXP >= 500 { mul("Усталость дня · больше 500 XP", 0.75) }

        xp = Fmt.jsRound(xp)
        if positiveToday.isEmpty {
            xp += 10
            steps.append(Step(name: "Первое дело за день", val: "+10"))
            if let d = ctx.daysSinceAny, d >= 3 {
                xp += 20
                steps.append(Step(name: "С возвращением", val: "+20"))
            }
        }
        return Assessment(skill: skill, xp: Int(xp), steps: steps, sure: skill != .misc)
    }

    /// Минус из словаря или «не пошёл в зал» — минус тому навыку, о котором речь.
    private static func minusRule(_ t: String) -> Minus? {
        if let m = Rules.minuses.first(where: { $0.rx.test(t) }) { return m }
        guard Rules.negated.test(t) else { return nil }
        let s = detectSkill(t)
        return Minus(rx: Rules.negated, xp: -15, skill: s == .misc ? .work : s, label: "Не сделал")
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

/// Числа из текста: минуты, километры, шаги, страницы, главы, повторы, задачи, слова.
public struct Quantities: Sendable {
    public var minutes: Double?
    public var km: Double?
    public var steps: Double?
    public var pages: Double?
    public var chapters: Double?
    public var reps: Double?
    public var tasks: Double?
    public var words: Double?

    private static let hoursMinutes = Rx("(\\d+(?:[.,]\\d+)?)\\s*(?:ч|час)[а-я]*\\s*(\\d+)\\s*м")
    private static let hours = Rx("(\\d+(?:[.,]\\d+)?)\\s*(?:ч(?![а-я])|час)")
    private static let mins = Rx("(\\d+)\\s*мин")
    private static let hourWord = Rx("(?<![а-я])час(?![а-я])")
    private static let kmRx = Rx("(\\d+(?:[.,]\\d+)?)\\s*(?:км|килом)")
    private static let metersRx = Rx("(?<![ч\\d.,])(\\d+)\\s*(?:м(?![а-я])|метр)")
    private static let stepsRx = Rx("(\\d+)\\s*шаг")
    private static let pagesRx = Rx("(\\d+)\\s*стр")
    private static let chaptersRx = Rx("(\\d+)\\s*глав")
    private static let setsRx = Rx("(\\d+)\\s*подход[а-я]*\\s*по\\s*(\\d+)")
    private static let repsRx = Rx("(\\d+)\\s*(?:раз(?:а|ов)?(?![а-я])|отжим|подтяг|присед|повтор)")
    private static let tasksRx = Rx("(\\d+)\\s*(?:задач|тикет|баг)")
    private static let wordsRx = Rx("(\\d+)\\s*слов")

    /// `t` — текст после `Assessor.prepare`.
    public init(_ t: String) {
        func n(_ s: String?) -> Double { Double((s ?? "0").replacingOccurrences(of: ",", with: ".")) ?? 0 }
        if let g = Self.hoursMinutes.groups(t) { minutes = n(g[1]) * 60 + n(g[2]) }
        else if let g = Self.hours.groups(t) { minutes = n(g[1]) * 60 }
        else if let g = Self.mins.groups(t) { minutes = n(g[1]) }
        else if t.contains("полчаса") { minutes = 30 }
        else if t.contains("час с половиной") { minutes = 90 }
        else if t.contains("весь день") || t.contains("целый день") { minutes = 300 }
        else if t.contains("весь вечер") || t.contains("целый вечер") { minutes = 180 }
        else if Self.hourWord.test(t) { minutes = 60 }
        if let g = Self.kmRx.groups(t) { km = n(g[1]) }
        else if let g = Self.metersRx.groups(t) { km = n(g[1]) / 1000 }
        if let g = Self.stepsRx.groups(t) { steps = n(g[1]) }
        if let g = Self.pagesRx.groups(t) { pages = n(g[1]) }
        if let g = Self.chaptersRx.groups(t) { chapters = n(g[1]) }
        if let g = Self.setsRx.groups(t) { reps = n(g[1]) * n(g[2]) }
        else if let g = Self.repsRx.groups(t) { reps = n(g[1]) }
        if let g = Self.tasksRx.groups(t) { tasks = n(g[1]) }
        if let g = Self.wordsRx.groups(t) { words = n(g[1]) }
    }

    /// Первая найденная мера по порядку эталона. Объём идёт под корнем, от ×0,5 до ×3.
    func effort(skill: Skill, text t: String) -> (k: Double, label: String)? {
        let distanceNorm = Rules.distance.first { $0.0.test(t) }?.1 ?? 3
        let minuteNorm = skill == .rest && Rules.sleep.test(t) ? 480 : skill.minuteNorm
        let norms: [(Double?, Double, (Double) -> String)] = [
            (km, distanceNorm, { "\(Fmt.k($0)) км" }),
            (steps, 8000, { "\(Fmt.plain($0)) шагов" }),
            (pages, 20, { "\(Fmt.plain($0)) стр." }),
            (chapters, 1, { v in "\(Fmt.plain(v)) \(Fmt.plural(Int(v), "глава", "главы", "глав"))" }),
            (reps, 30, { "\(Fmt.plain($0)) повт." }),
            (tasks, 2, { v in "\(Fmt.plain(v)) \(Fmt.plural(Int(v), "задача", "задачи", "задач"))" }),
            (words, 20, { "\(Fmt.plain($0)) слов" }),
            (minutes, minuteNorm, { Fmt.duration(minutes: $0) }),
        ]
        for (value, norm, label) in norms {
            if let v = value { return (clamp((v / norm).squareRoot(), 0.5, 3), label(v)) }
        }
        return nil
    }
}
