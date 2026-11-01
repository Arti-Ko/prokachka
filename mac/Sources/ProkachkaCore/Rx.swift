import Foundation

/// Обёртка над NSRegularExpression. Шаблоны приходят из эталона уже с явными границами слов:
/// `\b` в ICU и JS по-разному ведёт себя на кириллице.
struct Rx: @unchecked Sendable {
    let re: NSRegularExpression

    init(_ pattern: String) {
        // Шаблоны статические и сверяются тестами: ошибка здесь — ошибка в коде, не в данных.
        re = try! NSRegularExpression(pattern: pattern)
    }

    func test(_ s: String) -> Bool {
        re.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)) != nil
    }

    /// Группы первого совпадения; nil, если совпадения нет.
    func groups(_ s: String) -> [String?]? {
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return Self.groups(m, ns)
    }

    /// Замена всех совпадений, как `String.replace(/…/g, fn)` в JS.
    func replace(_ s: String, _ transform: ([String?]) -> String) -> String {
        let ns = s as NSString
        var out = "", last = 0
        for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            out += transform(Self.groups(m, ns))
            last = m.range.location + m.range.length
        }
        return out + ns.substring(from: last)
    }

    private static func groups(_ m: NSTextCheckingResult, _ ns: NSString) -> [String?] {
        (0..<m.numberOfRanges).map { i in
            let r = m.range(at: i)
            return r.location == NSNotFound ? nil : ns.substring(with: r)
        }
    }
}

struct Minus {
    let rx: Rx
    let xp: Double
    let skill: Skill
    let label: String
    var perHour = false
}
