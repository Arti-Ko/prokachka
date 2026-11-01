import Foundation
import XCTest
@testable import ProkachkaCore

final class SyncTests: XCTestCase {
    private static let file = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("spec/vectors/sync.json")

    private struct CryptoVector: Codable { let key: String; let nonce: String; let plain: String; let combined: String }

    func testCryptoRoundTripAndTamper() throws {
        let key = SyncCrypto.newKey()
        let sealed = try SyncCrypto.seal(Data("привет".utf8), key: key)
        XCTAssertEqual(String(data: try SyncCrypto.open(sealed, key: key), encoding: .utf8), "привет")
        var broken = sealed
        broken[broken.count - 1] ^= 0xFF
        XCTAssertThrowsError(try SyncCrypto.open(broken, key: key))
        XCTAssertThrowsError(try SyncCrypto.open(sealed, key: SyncCrypto.newKey()))
    }

    /// Вектор, который читает и Kotlin: тот же ключ и nonce дают те же байты.
    func testCryptoVectorSharedWithKotlin() throws {
        if ProcessInfo.processInfo.environment["UPDATE_SPEC"] == "1" {
            let key = Data((0..<32).map { UInt8($0) }), nonce = Data((0..<12).map { UInt8(200 + $0) })
            let plain = Data(#"{"device":"phone-1","ids":["a","б"]}"#.utf8)
            let v = CryptoVector(key: key.base64EncodedString(), nonce: nonce.base64EncodedString(), plain: String(data: plain, encoding: .utf8)!,
                                 combined: try SyncCrypto.seal(plain, key: key, nonce: nonce).base64EncodedString())
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            try enc.encode(v).write(to: Self.file)
        }
        let v = try JSONDecoder().decode(CryptoVector.self, from: Data(contentsOf: Self.file))
        let key = Data(base64Encoded: v.key)!, nonce = Data(base64Encoded: v.nonce)!
        XCTAssertEqual(try SyncCrypto.seal(Data(v.plain.utf8), key: key, nonce: nonce).base64EncodedString(), v.combined)
        XCTAssertEqual(String(data: try SyncCrypto.open(Data(base64Encoded: v.combined)!, key: key), encoding: .utf8), v.plain)
    }

    func testDiffSendsMissingAndAsksForUnknown() {
        let e = { (id: String) in Event(id: id, kind: .act, ts: 1, day: "2026-11-01", device: "mac", text: "x", skill: .work, xp: 1, steps: []) }
        let r = SyncResponse.diff(local: [e("a"), e("b"), e("c")], remoteIds: ["b", "d"])
        XCTAssertEqual(r.events.map(\.id), ["a", "c"])
        XCTAssertEqual(r.need, ["d"])
    }

    func testHTTPParsingWaitsForWholeBody() {
        let raw = Data("POST /sync HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\nX-Device: phone-1\r\n\r\nhel".utf8)
        XCTAssertEqual(MiniHTTPRequest.parse(raw), .incomplete)
        guard case let .done(req, consumed) = MiniHTTPRequest.parse(raw + Data("lo".utf8)) else { return XCTFail("не разобран") }
        XCTAssertEqual(req.path, "/sync")
        XCTAssertEqual(req.headers["x-device"], "phone-1")
        XCTAssertEqual(req.body, Data("hello".utf8))
        XCTAssertEqual(consumed, raw.count + 2)
        XCTAssertEqual(MiniHTTPRequest.parse(Data("GARBAGE\r\n\r\n".utf8)), .invalid)
    }
}
