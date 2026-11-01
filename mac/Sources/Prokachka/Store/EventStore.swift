import Foundation
import Observation
import ProkachkaCore

/// Уведомление внутри приложения: квест, достижение, рост навыка.
struct Banner: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let body: String
}

struct LevelUp: Identifiable, Equatable {
    let level: Int
    let rank: String
    var id: Int { level }
}

/// Награда из своего магазина. Каталог — настройка, а не журнал: его не нужно сливать по событиям.
struct Reward: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    var title: String
    var cost: Int
    var symbol: String
}

/// Журнал событий на диске и снимок, выведенный из него.
/// Файл events.jsonl только дописывается — его же потом будет сливать синхронизация.
@MainActor @Observable
final class EventStore {
    static let shared = EventStore()

    private(set) var events: [Event] = []
    private(set) var snapshot: Snapshot
    private(set) var rewards: [Reward] = []
    var banners: [Banner] = []
    var levelUp: LevelUp?
    /// Последняя ошибка чтения или записи — показывается в окне, а не теряется.
    var problem: String?
    /// Последнее добавленное дело: подсветить строку и показать «+XP».
    private(set) var lastAdded: (id: String, xp: Int)?

    let clock = DayClock()
    let deviceId: String
    private let directory: URL
    private var eventsURL: URL { directory.appendingPathComponent("events.jsonl") }
    private var rewardsURL: URL { directory.appendingPathComponent("rewards.json") }

    init(directory: URL? = nil) {
        // PROKACHKA_DATA_DIR — отдельная папка данных для проверок, чтобы не трогать настоящий журнал.
        let custom = ProcessInfo.processInfo.environment["PROKACHKA_DATA_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        let base = directory ?? custom ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Prokachka", isDirectory: true)
        self.directory = base
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: "deviceId") {
            deviceId = id
        } else {
            deviceId = "mac-" + UUID().uuidString.prefix(8).lowercased()
            defaults.set(deviceId, forKey: "deviceId")
        }
        snapshot = Ledger.snapshot([], today: DayClock().key(Date()))
        load()
        watchDayChange()
    }

    var today: String { clock.key(Date()) }

    func preview(_ text: String, override: Skill?) -> Assessment? {
        Assessor.assess(text, snapshot.context(override: override))
    }

    /// Записать дело. Возвращает оценку, если текст удалось разобрать.
    @discardableResult
    func add(_ raw: String, override: Skill? = nil) -> Assessment? {
        recomputeIfDayChanged()
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let a = preview(text, override: override) else { return nil }
        let before = snapshot
        let ts = Self.nowMs()
        let act = Event.act(text, a, ts: ts, day: today, device: deviceId)
        guard append([act]) else { return nil }
        let due = snapshot.dueQuestEvents(ts: ts + 1, device: deviceId)
        if !due.isEmpty { append(due) }
        lastAdded = (act.id, a.xp)
        announce(from: before, quests: due)
        return a
    }

    func tune(_ entry: Entry, _ tune: Event.Tune) {
        let before = snapshot
        append([Event.edit(entry.id, tune, ts: Self.nowMs(), day: today, device: deviceId)])
        if let k = snapshot.calibration[entry.skill], k != before.calibration[entry.skill] {
            post("Учту на будущее", "«\(entry.skill.title)» теперь оценивается ×\(Fmt.k(k))")
        }
    }

    func delete(_ entry: Entry) {
        append([Event.delete(entry.id, ts: Self.nowMs(), day: today, device: deviceId)])
    }

    func take(_ reward: Reward) {
        guard snapshot.coins >= reward.cost else { return }
        if append([Event.spend(reward.title, cost: reward.cost, ts: Self.nowMs(), day: today, device: deviceId)]) {
            post("Награда твоя", "\(reward.title) · −\(reward.cost) монет")
        }
    }

    func addReward(title: String, cost: Int) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, cost > 0 else { return }
        rewards.append(Reward(title: t, cost: cost, symbol: "gift.fill"))
        saveRewards()
    }

    func removeReward(_ reward: Reward) {
        rewards.removeAll { $0.id == reward.id }
        saveRewards()
    }

    func dismiss(_ banner: Banner) { banners.removeAll { $0.id == banner.id } }

    // MARK: - журнал на диске

    private func load() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: eventsURL.path) {
                let text = try String(contentsOf: eventsURL, encoding: .utf8)
                var broken = 0
                let decoder = JSONDecoder()
                events = text.split(separator: "\n").compactMap { line in
                    do { return try decoder.decode(Event.self, from: Data(line.utf8)) } catch { broken += 1; return nil }
                }
                if broken > 0 { problem = "\(broken) \(Fmt.plural(broken, "строка", "строки", "строк")) журнала не прочитаны и пропущены. Файл: \(eventsURL.path)" }
            }
            rewards = FileManager.default.fileExists(atPath: rewardsURL.path)
                ? try JSONDecoder().decode([Reward].self, from: Data(contentsOf: rewardsURL))
                : Self.defaultRewards
        } catch {
            problem = "Не удалось прочитать данные: \(error.localizedDescription)"
            rewards = Self.defaultRewards
        }
        recompute()
    }

    /// Сначала диск, потом память: если запись не удалась, интерфейс не покажет несохранённое.
    @discardableResult
    private func append(_ new: [Event]) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            var chunk = Data()
            for e in new {
                chunk.append(try encoder.encode(e))
                chunk.append(0x0A)
            }
            if !FileManager.default.fileExists(atPath: eventsURL.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                FileManager.default.createFile(atPath: eventsURL.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: eventsURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: chunk)
            events.append(contentsOf: new)
            recompute()
            return true
        } catch {
            problem = "Не удалось сохранить запись: \(error.localizedDescription)"
            return false
        }
    }

    private func saveRewards() {
        do {
            try JSONEncoder().encode(rewards).write(to: rewardsURL, options: .atomic)
        } catch {
            problem = "Не удалось сохранить награды: \(error.localizedDescription)"
        }
    }

    private func recompute() { snapshot = Ledger.snapshot(events, today: today, clock: clock) }

    private func recomputeIfDayChanged() { if snapshot.today != today { recompute() } }

    /// В 04:00 начинается новый день: обновить стрик и квесты, даже если ничего не записывали.
    private func watchDayChange() {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                self?.recomputeIfDayChanged()
            }
        }
    }

    // MARK: - оповещения

    private func announce(from before: Snapshot, quests: [Event]) {
        let after = snapshot
        for q in quests { post("Квест выполнен", "\(q.text ?? "") · +\(q.xp ?? 0) XP") }
        let was = Dictionary(uniqueKeysWithValues: before.achievements.map { ($0.id, $0.done) })
        for a in after.achievements where a.done && was[a.id] == false { post("Новое достижение", "\(a.title): \(a.text.lowercased())") }
        for s in Skill.trained {
            let l = after.skills[s]?.info.level ?? 1
            if l > (before.skills[s]?.info.level ?? 1) { post("\(s.title): уровень \(l)", "Навык вырос") }
        }
        if after.level.level > before.level.level { levelUp = LevelUp(level: after.level.level, rank: after.rank) }
    }

    private func post(_ title: String, _ body: String) {
        let b = Banner(title: title, body: body)
        banners.insert(b, at: 0)
        if banners.count > 3 { banners.removeLast() }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            self?.dismiss(b)
        }
    }

    private static func nowMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

    private static let defaultRewards = [
        Reward(title: "Серия сериала без чувства вины", cost: 40, symbol: "tv.fill"),
        Reward(title: "Кофе в любимой кофейне", cost: 60, symbol: "cup.and.saucer.fill"),
        Reward(title: "Вечер игр", cost: 150, symbol: "gamecontroller.fill"),
        Reward(title: "Выходной без планов", cost: 500, symbol: "sun.max.fill"),
        Reward(title: "Новая игра", cost: 900, symbol: "gift.fill"),
    ]
}
