import Foundation
import Network
import Observation
import ProkachkaCore

struct PairedDevice: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var lastSync: Date?
}

struct SyncSettings: Codable {
    /// Общий ключ AES-256, base64. Появляется при первом сопряжении.
    var key: String?
    var devices: [PairedDevice] = []
}

/// Сервер синхронизации по локальной сети (spec/sync.md): объявляет себя через Bonjour,
/// телефон находит его сам, сопрягается по 6-значному коду и дальше обменивается зашифрованными журналами.
@MainActor @Observable
final class SyncServer {
    static let shared = SyncServer()

    private(set) var status = "Запускается…"
    private(set) var isListening = false
    private(set) var settings = SyncSettings()
    private(set) var code: String?
    private(set) var codeUntil: Date?
    let name = Host.current().localizedName ?? "Mac"

    private var attempts = 0
    private var listener: NWListener?
    private let store = EventStore.shared
    private var settingsURL: URL { store.dataDirectory.appendingPathComponent("sync.json") }

    /// Буфер соединения. Трогается только на главной очереди.
    private final class Buffer: @unchecked Sendable { var data = Data() }

    func start() {
        guard listener == nil else { return }
        load()
        listen()
    }

    func newCode() {
        code = String(format: "%06d", Int.random(in: 0..<1_000_000))
        codeUntil = Date().addingTimeInterval(SyncProtocol.codeLifetime)
        attempts = 0
    }

    /// Код показывается сам, пока не подключено ни одного устройства; дальше — по кнопке «Новый код».
    func ensureCode() {
        guard settings.devices.isEmpty else { return }
        if code == nil || (codeUntil ?? .distantPast) < Date() { newCode() }
    }

    /// Отключённое устройство больше не принимается. Если не осталось ни одного — ключ сбрасывается.
    func remove(_ device: PairedDevice) {
        settings.devices.removeAll { $0.id == device.id }
        if settings.devices.isEmpty { settings.key = nil }
        save()
    }

    // MARK: - сеть

    private func listen() {
        do {
            let l = try NWListener(using: .tcp)
            l.service = NWListener.Service(name: "Прокачка · \(name)", type: SyncProtocol.serviceType, domain: nil,
                                           txtRecord: NWTXTRecord(["device": store.deviceId]))
            l.stateUpdateHandler = { [weak self] state in Task { @MainActor in self?.update(state) } }
            l.newConnectionHandler = { [weak self] conn in Task { @MainActor in self?.serve(conn) } }
            listener = l
            l.start(queue: .main)
        } catch {
            status = "Не удалось открыть порт: \(error.localizedDescription)"
        }
    }

    private func update(_ state: NWListener.State) {
        switch state {
        case .ready:
            isListening = true
            status = "Ждёт телефон в этой сети Wi‑Fi"
        case .waiting(let error):
            isListening = false
            status = "Нет сети: \(error.localizedDescription)"
        case .failed(let error):
            isListening = false
            status = "Сервер остановился: \(error.localizedDescription). Перезапускаю…"
            listener?.cancel()
            listener = nil
            Task {
                try? await Task.sleep(for: .seconds(5))
                self.listen()
            }
        default:
            break
        }
    }

    private func serve(_ conn: NWConnection) {
        conn.start(queue: .main)
        let buffer = Buffer()
        func read() {
            conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) { data, _, done, error in
                Task { @MainActor in
                    if let data { buffer.data.append(data) }
                    switch MiniHTTPRequest.parse(buffer.data) {
                    case let .done(req, _): self.reply(conn, self.route(req))
                    case .invalid: self.reply(conn, (400, Data()))
                    case .incomplete:
                        if done || error != nil { conn.cancel() } else { read() }
                    }
                }
            }
        }
        read()
    }

    private func reply(_ conn: NWConnection, _ r: (Int, Data)) {
        conn.send(content: MiniHTTPRequest.response(status: r.0, body: r.1), completion: .contentProcessed { _ in conn.cancel() })
    }

    private func route(_ req: MiniHTTPRequest) -> (Int, Data) {
        guard req.method == "POST" else { return (404, Data()) }
        switch req.path {
        case "/pair": return pair(req.body)
        case "/sync", "/push": return secured(req)
        default: return (404, Data())
        }
    }

    private func text(_ s: String) -> Data { Data(s.utf8) }

    private func pair(_ body: Data) -> (Int, Data) {
        guard let r = try? JSONDecoder().decode(PairRequest.self, from: body) else { return (400, Data()) }
        guard let code, let until = codeUntil, until > Date() else {
            return (410, text("Код устарел. На Mac откройте «Синхронизацию» — там новый."))
        }
        guard r.code == code else {
            attempts += 1
            // Перебор шести цифр по сети не пройдёт: после 5 ошибок код сгорает.
            if attempts >= SyncProtocol.maxCodeAttempts { self.code = nil }
            return (403, text("Неверный код"))
        }
        let key = settings.key ?? SyncCrypto.newKey().base64EncodedString()
        settings.key = key
        settings.devices.removeAll { $0.id == r.device }
        settings.devices.append(PairedDevice(id: r.device, name: r.name, lastSync: Date()))
        save()
        self.code = nil
        codeUntil = nil
        guard let out = try? JSONEncoder().encode(PairResponse(key: key, device: store.deviceId, name: name)) else { return (500, Data()) }
        return (200, out)
    }

    private func secured(_ req: MiniHTTPRequest) -> (Int, Data) {
        guard let device = req.headers["x-device"], let i = settings.devices.firstIndex(where: { $0.id == device }),
              let key = settings.key.flatMap({ Data(base64Encoded: $0) }) else {
            return (403, text("Телефон не подключён к этому Mac"))
        }
        guard let plain = try? SyncCrypto.open(req.body, key: key) else { return (401, text("Ключ не подходит — подключите телефон заново")) }
        do {
            let out: Data
            if req.path == "/sync" {
                let r = try JSONDecoder().decode(SyncRequest.self, from: plain)
                out = try JSONEncoder().encode(SyncResponse.diff(local: store.allEvents, remoteIds: r.ids))
            } else {
                let r = try JSONDecoder().decode(PushRequest.self, from: plain)
                out = try JSONEncoder().encode(PushResponse(accepted: store.importEvents(r.events, from: settings.devices[i].name)))
            }
            settings.devices[i].lastSync = Date()
            save()
            return (200, try SyncCrypto.seal(out, key: key))
        } catch {
            return (400, text("Не удалось разобрать запрос: \(error.localizedDescription)"))
        }
    }

    // MARK: - настройки на диске

    private func load() {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return }
        do {
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            settings = try dec.decode(SyncSettings.self, from: Data(contentsOf: settingsURL))
        } catch {
            store.problem = "Не удалось прочитать настройки синхронизации: \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .iso8601
            try enc.encode(settings).write(to: settingsURL, options: [.atomic])
            // В файле ключ: читать его может только владелец.
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: settingsURL.path)
        } catch {
            store.problem = "Не удалось сохранить настройки синхронизации: \(error.localizedDescription)"
        }
    }
}
