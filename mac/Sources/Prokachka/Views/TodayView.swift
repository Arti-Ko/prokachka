import SwiftUI
import ProkachkaCore

struct TodayView: View {
    @Environment(EventStore.self) private var store

    var body: some View {
        let s = store.snapshot
        Form {
            SwiftUI.Section { LevelHeader(snapshot: s) }
            SwiftUI.Section { Composer() }
            SwiftUI.Section {
                if s.todayEntries.isEmpty {
                    Text("Пока пусто. Напиши, что сделал, — даже мелочь считается.").foregroundStyle(.secondary)
                } else {
                    ForEach(s.todayEntries) { EntryRow(entry: $0) }
                }
            } header: {
                HStack {
                    Text("Сегодня · \(s.todayEntries.count) \(Fmt.plural(s.todayEntries.count, "запись", "записи", "записей"))")
                    Spacer()
                    Text("\(Fmt.signed(Double(s.todayXP))) XP").monospacedDigit()
                }
            }
            SwiftUI.Section("Квесты дня") {
                ForEach(s.quests.filter { $0.period == .day }) { QuestRow(quest: $0) }
            }
        }
        .formStyle(.grouped)
    }
}

struct LevelHeader: View {
    let snapshot: Snapshot

    var body: some View {
        let l = snapshot.level
        HStack(spacing: 16) {
            LevelRing(progress: l.progress, level: l.level, size: 80, line: 8)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text("Уровень \(l.level)").font(.title3.weight(.semibold))
                    Text("· \(snapshot.rank)").font(.title3).foregroundStyle(.secondary)
                }
                ProgressView(value: l.progress)
                Text("\(l.into) из \(l.need) XP · до \(l.level + 1)-го \(l.need - l.into)")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                HStack(spacing: 6) {
                    Badge(symbol: "flame.fill", tint: .orange, text: Fmt.days(snapshot.streak) + " подряд")
                    Badge(symbol: "bolt.fill", tint: .accentColor, text: "\(Fmt.signed(Double(snapshot.todayXP))) сегодня")
                    Badge(symbol: "circle.circle.fill", tint: .orange, text: "\(snapshot.coins) \(Fmt.plural(snapshot.coins, "монета", "монеты", "монет"))")
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct Badge: View {
    let symbol: String
    let tint: Color
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(text).monospacedDigit()
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.quaternary.opacity(0.5), in: Capsule())
    }
}

struct QuestRow: View {
    let quest: QuestState

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: quest.done ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(quest.done ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(quest.title)
                if quest.goal > 1 && !quest.done {
                    ProgressView(value: Double(quest.progress), total: Double(quest.goal)).tint(quest.skill?.color)
                }
            }
            Spacer()
            Text(quest.done ? "Готово" : "\(quest.progress) из \(quest.goal)").foregroundStyle(.secondary).monospacedDigit()
            Text("+\(quest.xp) XP").font(.callout.weight(.medium)).monospacedDigit().frame(minWidth: 62, alignment: .trailing)
        }
    }
}
