import Foundation

/// Числа и подписи ровно так, как их пишет эталон (ru-RU, JS Math.round).
/// От этих строк зависят тест-векторы, поэтому без NumberFormatter: он зависит от системы.
public enum Fmt {
    /// Math.round из JS: половина всегда вверх, в том числе для отрицательных.
    public static func jsRound(_ x: Double) -> Double { (x + 0.5).rounded(.down) }

    /// Целое с разрядами по-русски: 1000 → «1000», 10000 → «10 000».
    public static func int(_ n: Double) -> String {
        let v = Int(jsRound(n))
        let digits = String(abs(v))
        guard digits.count >= 5 else { return v < 0 ? "-" + digits : digits }
        var out = ""
        for (i, ch) in digits.enumerated() {
            if i > 0 && (digits.count - i) % 3 == 0 { out.append("\u{00A0}") }
            out.append(ch)
        }
        return v < 0 ? "-" + out : out
    }

    /// «+12», «−20», «0» — с типографским минусом.
    public static func signed(_ n: Double) -> String {
        let sign = n > 0 ? "+" : n < 0 ? "\u{2212}" : ""
        return sign + int(abs(n))
    }

    /// Множитель: два знака после запятой без хвостовых нулей. 1.5 → «1,5», 2 → «2».
    public static func k(_ x: Double) -> String {
        let r = jsRound(x * 100) / 100
        var s = String(format: "%.2f", r)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s.replacingOccurrences(of: ".", with: ",")
    }

    /// 45 → «45 мин», 90 → «1,5 ч».
    public static func duration(minutes m: Double) -> String {
        m >= 60 ? "\(k(jsRound(m / 6) / 10)) ч" : "\(int(m)) мин"
    }

    /// Число из текста, как его печатает JS: 30 → «30», 2.5 → «2.5».
    static func plain(_ x: Double) -> String {
        x == x.rounded() ? String(Int(x)) : String(x)
    }

    public static func plural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let m10 = n % 10, m100 = n % 100
        if m10 == 1 && m100 != 11 { return one }
        if (2...4).contains(m10) && (m100 < 12 || m100 > 14) { return few }
        return many
    }

    public static func days(_ n: Int) -> String { "\(n) \(plural(n, "день", "дня", "дней"))" }
}
