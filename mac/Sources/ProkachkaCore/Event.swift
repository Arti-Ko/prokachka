import Foundation

/// Запись журнала. Журнал только дописывается: правка и удаление — тоже события.
/// Поэтому слияние журналов двух устройств — объединение по `id`, без конфликтов.
public struct Event: Codable, Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case act, quest, edit, delete, spend }

    /// Правка оценки: «мало» поднимает и запись, и навык; «много» опускает; «строго» смягчает минус.
    public enum Tune: String, Codable, Sendable {
        case up, down, soft

        public var factor: Double {
            switch self {
            case .up: 1.25
            case .down: 0.8
            case .soft: 0.5
            }
        }

        /// Насколько правка сдвигает калибровку навыка. У «строго» сдвига нет.
        var calibration: Double? {
            switch self {
            case .up: 1.1
            case .down: 0.9
            case .soft: nil
            }
        }

        var label: String {
            switch self {
            case .up: "Твоя правка: мало"
            case .down: "Твоя правка: много"
            case .soft: "Твоя правка: строго"
            }
        }
    }

    public let id: String
    public let kind: Kind
    /// Миллисекунды с 1970-01-01.
    public let ts: Int64
    /// Учётный день «гггг-мм-дд» с началом в 04:00, считается на устройстве в момент записи.
    public let day: String
    public let device: String
    public var text: String?
    public var skill: Skill?
    public var xp: Int?
    public var steps: [Step]?
    public var target: String?
    public var tune: Tune?
    public var cost: Int?

    public init(id: String, kind: Kind, ts: Int64, day: String, device: String, text: String? = nil, skill: Skill? = nil,
                xp: Int? = nil, steps: [Step]? = nil, target: String? = nil, tune: Tune? = nil, cost: Int? = nil) {
        self.id = id
        self.kind = kind
        self.ts = ts
        self.day = day
        self.device = device
        self.text = text
        self.skill = skill
        self.xp = xp
        self.steps = steps
        self.target = target
        self.tune = tune
        self.cost = cost
    }

    public static func act(_ text: String, _ a: Assessment, ts: Int64, day: String, device: String, id: String = UUID().uuidString) -> Event {
        Event(id: id, kind: .act, ts: ts, day: day, device: device, text: text, skill: a.skill, xp: a.xp, steps: a.steps)
    }

    public static func edit(_ target: String, _ tune: Tune, ts: Int64, day: String, device: String) -> Event {
        Event(id: UUID().uuidString, kind: .edit, ts: ts, day: day, device: device, target: target, tune: tune)
    }

    public static func delete(_ target: String, ts: Int64, day: String, device: String) -> Event {
        Event(id: UUID().uuidString, kind: .delete, ts: ts, day: day, device: device, target: target)
    }

    public static func spend(_ title: String, cost: Int, ts: Int64, day: String, device: String) -> Event {
        Event(id: UUID().uuidString, kind: .spend, ts: ts, day: day, device: device, text: title, cost: cost)
    }

    /// Порядок журнала: по времени, при равенстве по id — одинаково на всех устройствах.
    static func chronological(_ a: Event, _ b: Event) -> Bool { a.ts != b.ts ? a.ts < b.ts : a.id < b.id }
}

/// Учётные дни. День начинается в 04:00: дело в час ночи засчитывается вчерашнему дню.
public struct DayClock: Sendable {
    public var timeZone: TimeZone
    public var startHour: Int

    public init(timeZone: TimeZone = .current, startHour: Int = 4) {
        self.timeZone = timeZone
        self.startHour = startHour
    }

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        return c
    }

    public func key(_ date: Date) -> String {
        let shifted = date.addingTimeInterval(-Double(startHour) * 3600)
        let c = calendar.dateComponents([.year, .month, .day], from: shifted)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    public func key(ms: Int64) -> String { key(Date(timeIntervalSince1970: Double(ms) / 1000)) }

    public func hour(ms: Int64) -> Int {
        calendar.component(.hour, from: Date(timeIntervalSince1970: Double(ms) / 1000))
    }

    // Арифметика над ключами дней — в UTC, чтобы переход на летнее время её не сдвигал.
    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    static func date(_ key: String) -> Date? {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return utc.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }

    public static func shift(_ key: String, by days: Int) -> String {
        guard let d = date(key), let r = utc.date(byAdding: .day, value: days, to: d) else { return key }
        let c = utc.dateComponents([.year, .month, .day], from: r)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    /// Понедельник недели, к которой относится день.
    public static func weekStart(_ key: String) -> String {
        guard let d = date(key) else { return key }
        let weekday = utc.component(.weekday, from: d) // 1 — воскресенье
        return shift(key, by: -((weekday + 5) % 7))
    }
}
