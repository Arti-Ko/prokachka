import Foundation

public struct LevelInfo: Equatable, Codable, Sendable {
    public let level: Int
    /// Сколько опыта было на старте текущего уровня.
    public let start: Int
    public let into: Int
    public let need: Int

    public var progress: Double { need > 0 ? Double(into) / Double(need) : 0 }
}

/// Кривая уровней. Общий уровень: 100 × L^1,4 на переход, навыки: 60 × L^1,3.
public enum Levels {
    public static func req(_ level: Int) -> Int { Int(Fmt.jsRound(100 * pow(Double(level), 1.4))) }
    public static func skillReq(_ level: Int) -> Int { Int(Fmt.jsRound(60 * pow(Double(level), 1.3))) }

    public static func info(_ total: Int, req: (Int) -> Int = Levels.req) -> LevelInfo {
        var level = 1, start = 0
        while total - start >= req(level) {
            start += req(level)
            level += 1
        }
        return LevelInfo(level: level, start: start, into: total - start, need: req(level))
    }

    public static func skill(_ total: Int) -> LevelInfo { info(total, req: skillReq) }

    /// Звание по уровню.
    public static func rank(_ level: Int) -> String {
        switch level {
        case 20...: "Легенда"
        case 15...: "Мастер"
        case 10...: "Практик"
        case 5...: "Ученик"
        default: "Новичок"
        }
    }

    /// Сколько опыта нужно от текущей точки до уровня `target`.
    public static func xpTo(_ target: Int, from info: LevelInfo) -> Int {
        guard target > info.level else { return 0 }
        return (info.level..<target).reduce(-info.into) { $0 + req($1) }
    }
}
