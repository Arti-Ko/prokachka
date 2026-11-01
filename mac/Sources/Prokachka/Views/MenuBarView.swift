import SwiftUI
import ProkachkaCore

/// Окно из строки меню: уровень, быстрая запись, последние дела.
struct MenuBarView: View {
    @Environment(EventStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let s = store.snapshot
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                LevelRing(progress: s.level.progress, level: s.level.level, size: 40, line: 4.5)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Уровень \(s.level.level) · \(s.rank)").font(.headline)
                    Text("\(Fmt.signed(Double(s.todayXP))) XP сегодня · \(Fmt.days(s.streak)) подряд")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            Composer(compact: true, autofocus: true)
            if !s.todayEntries.isEmpty {
                VStack(spacing: 6) {
                    ForEach(s.todayEntries.prefix(3)) { EntryRow(entry: $0, editable: false) }
                }
            }
            Divider()
            HStack {
                Button("Открыть Прокачку") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Text("⌥ Пробел — запись отовсюду").font(.caption).foregroundStyle(.tertiary)
                Button("Выйти") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 360)
    }
}
