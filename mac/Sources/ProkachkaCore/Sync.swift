import CryptoKit
import Foundation

/// Синхронизация по локальной сети (spec/sync.md). Mac — сервер, телефон — клиент.
/// После сопряжения все сообщения шифруются общим ключом AES-256-GCM.
public enum SyncProtocol {
    public static let serviceType = "_prokachka._tcp"
    /// Код сопряжения живёт 5 минут и сгорает после 5 неверных попыток.
    public static let codeLifetime: TimeInterval = 300
    public static let maxCodeAttempts = 5
    /// Больше 16 МБ за раз не принимаем: журнал за годы весит меньше.
    public static let maxBody = 16 * 1024 * 1024
}

public struct PairRequest: Codable, Sendable {
    public let code: String
    public let device: String
    public let name: String

    public init(code: String, device: String, name: String) {
        self.code = code
        self.device = device
        self.name = name
    }
}

public struct PairResponse: Codable, Sendable {
    /// Общий ключ синхронизации, base64 от 32 байт.
    public let key: String
    public let device: String
    public let name: String

    public init(key: String, device: String, name: String) {
        self.key = key
        self.device = device
        self.name = name
    }
}

/// Шаг 1: телефон сообщает, какие события у него есть.
public struct SyncRequest: Codable, Sendable {
    public let device: String
    public let ids: [String]

    public init(device: String, ids: [String]) {
        self.device = device
        self.ids = ids
    }
}

/// Ответ Mac: события, которых нет у телефона, и id, которых нет у Mac.
public struct SyncResponse: Codable, Sendable {
    public let events: [Event]
    public let need: [String]

    public init(events: [Event], need: [String]) {
        self.events = events
        self.need = need
    }

    /// Разница журналов: что отдать собеседнику и что у него попросить.
    public static func diff(local: [Event], remoteIds: [String]) -> SyncResponse {
        let remote = Set(remoteIds)
        let mine = Set(local.map(\.id))
        return SyncResponse(events: local.filter { !remote.contains($0.id) }, need: remoteIds.filter { !mine.contains($0) })
    }
}

/// Шаг 2: телефон отдаёт события, которых не хватало Mac.
public struct PushRequest: Codable, Sendable {
    public let device: String
    public let events: [Event]

    public init(device: String, events: [Event]) {
        self.device = device
        self.events = events
    }
}

public struct PushResponse: Codable, Sendable {
    public let accepted: Int

    public init(accepted: Int) { self.accepted = accepted }
}

public enum SyncCrypto {
    public enum Failure: Error { case badKey, badMessage }

    public static func newKey() -> Data { SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) } }

    /// nonce (12 байт) + шифротекст + тег (16 байт) — тот же формат, что у Kotlin.
    public static func seal(_ plain: Data, key: Data, nonce: Data? = nil) throws -> Data {
        guard key.count == 32 else { throw Failure.badKey }
        let n = try nonce.map { try AES.GCM.Nonce(data: $0) } ?? AES.GCM.Nonce()
        guard let combined = try AES.GCM.seal(plain, using: SymmetricKey(data: key), nonce: n).combined else { throw Failure.badMessage }
        return combined
    }

    public static func open(_ combined: Data, key: Data) throws -> Data {
        guard key.count == 32 else { throw Failure.badKey }
        do {
            return try AES.GCM.open(AES.GCM.SealedBox(combined: combined), using: SymmetricKey(data: key))
        } catch {
            throw Failure.badMessage
        }
    }
}

/// Минимальный HTTP/1.1: один запрос на соединение, тело по Content-Length.
public struct MiniHTTPRequest: Equatable, Sendable {
    public let method: String
    public let path: String
    public let headers: [String: String]
    public let body: Data

    public enum Parse: Equatable { case incomplete, invalid, done(MiniHTTPRequest, consumed: Int) }

    public static func parse(_ buffer: Data) -> Parse {
        guard let headEnd = buffer.range(of: Data("\r\n\r\n".utf8)) else {
            return buffer.count > 16 * 1024 ? .invalid : .incomplete
        }
        guard let head = String(data: buffer[buffer.startIndex..<headEnd.lowerBound], encoding: .utf8) else { return .invalid }
        let lines = head.components(separatedBy: "\r\n")
        let first = lines[0].split(separator: " ")
        guard first.count >= 2 else { return .invalid }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            headers[line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        let length = Int(headers["content-length"] ?? "0") ?? -1
        guard length >= 0, length <= SyncProtocol.maxBody else { return .invalid }
        let bodyStart = headEnd.upperBound
        guard buffer.count - (bodyStart - buffer.startIndex) >= length else { return .incomplete }
        let body = buffer[bodyStart..<(bodyStart + length)]
        let req = MiniHTTPRequest(method: String(first[0]), path: String(first[1]), headers: headers, body: Data(body))
        return .done(req, consumed: bodyStart - buffer.startIndex + length)
    }

    public static func response(status: Int, body: Data, contentType: String = "application/octet-stream") -> Data {
        let reason = [200: "OK", 400: "Bad Request", 401: "Unauthorized", 403: "Forbidden", 404: "Not Found", 410: "Gone"][status] ?? "Error"
        var out = Data("HTTP/1.1 \(status) \(reason)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)
        out.append(body)
        return out
    }
}
