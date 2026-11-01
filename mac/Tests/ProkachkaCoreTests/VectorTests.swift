import Foundation
import XCTest
@testable import ProkachkaCore

/// Сверка с эталоном: spec/vectors генерирует spec/reference/gen-vectors.mjs из прототипа.
final class VectorTests: XCTestCase {
    private static let specDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("spec/vectors")

    private struct AssessFile: Decodable {
        struct Ctx: Decodable {
            struct Act: Decodable { let cat: String; let xp: Int; let text: String; let label: String }
            let dayActs: [Act]
            let streak: Int
            let cal: [String: Double]
            let lastTrained: [String: Int]
            let daysSinceAny: Int?
        }
        struct Expect: Decodable { let cat: String; let xp: Int; let steps: [Step]; let sure: Bool }
        struct Case: Decodable { let text: String; let context: String; let override: String?; let expect: Expect? }
        struct Hint: Decodable { let text: String; let hint: String? }
        struct Prepared: Decodable { let text: String; let prepared: String }
        let contexts: [String: Ctx]
        let cases: [Case]
        let hints: [Hint]
        let prepared: [Prepared]
    }

    private struct LevelCase: Decodable {
        struct Info: Decodable { let level: Int; let start: Int; let into: Int; let need: Int }
        let total: Int
        let level: Info
        let skill: Info
    }

    private func load<T: Decodable>(_ name: String, as: T.Type) throws -> T {
        let data = try Data(contentsOf: Self.specDir.appendingPathComponent(name))
        return try JSONDecoder().decode(T.self, from: data)
    }

    func testAssessMatchesReference() throws {
        let file = try load("assess.json", as: AssessFile.self)
        XCTAssertGreaterThan(file.cases.count, 100)
        for c in file.cases {
            let raw = try XCTUnwrap(file.contexts[c.context])
            let ctx = AssessContext(
                dayActs: raw.dayActs.map { DayAct(skill: Skill(rawValue: $0.cat)!, xp: $0.xp, text: $0.text, label: $0.label) },
                streak: raw.streak,
                calibration: Dictionary(uniqueKeysWithValues: raw.cal.map { (Skill(rawValue: $0.key)!, $0.value) }),
                lastTrained: Dictionary(uniqueKeysWithValues: raw.lastTrained.map { (Skill(rawValue: $0.key)!, $0.value) }),
                daysSinceAny: raw.daysSinceAny,
                override: c.override.flatMap(Skill.init(rawValue:))
            )
            let got = Assessor.assess(c.text, ctx)
            let where_ = "«\(c.text)» в контексте \(c.context)\(c.override.map { " +\($0)" } ?? "")"
            guard let expect = c.expect else {
                XCTAssertNil(got, where_)
                continue
            }
            guard let got else { XCTFail("nil для \(where_)"); continue }
            XCTAssertEqual(got.skill.rawValue, expect.cat, where_)
            XCTAssertEqual(got.xp, expect.xp, where_)
            XCTAssertEqual(got.sure, expect.sure, where_)
            XCTAssertEqual(got.steps, expect.steps, where_)
        }
    }

    func testHintsAndNumberWordsMatchReference() throws {
        let file = try load("assess.json", as: AssessFile.self)
        for h in file.hints { XCTAssertEqual(Assessor.hint(h.text)?.rawValue, h.hint, "подсказка для «\(h.text)»") }
        for p in file.prepared { XCTAssertEqual(Assessor.prepare(p.text), p.prepared) }
    }

    func testCatalogMatchesSpec() throws {
        struct Def: Decodable { let id: String; let metric: String; let goal: Int; let tier: Int; let hidden: Bool }
        let spec = try load("../achievements.json", as: [Def].self)
        XCTAssertEqual(spec.map(\.id), AchievementCatalog.all.map(\.id))
        XCTAssertEqual(spec.map(\.goal), AchievementCatalog.all.map(\.goal))
        XCTAssertGreaterThan(spec.count, 80)
    }

    func testLevelsMatchReference() throws {
        for c in try load("levels.json", as: [LevelCase].self) {
            let l = Levels.info(c.total), s = Levels.skill(c.total)
            XCTAssertEqual([l.level, l.start, l.into, l.need], [c.level.level, c.level.start, c.level.into, c.level.need], "уровень для \(c.total)")
            XCTAssertEqual([s.level, s.start, s.into, s.need], [c.skill.level, c.skill.start, c.skill.into, c.skill.need], "навык для \(c.total)")
        }
    }
}
