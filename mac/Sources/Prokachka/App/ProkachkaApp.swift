import AppKit
import Carbon.HIToolbox
import SwiftUI
import ProkachkaCore

@main
struct ProkachkaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = EventStore.shared

    var body: some Scene {
        Window("Прокачка", id: "main") {
            RootView()
                .environment(store)
                .frame(minWidth: 720, minHeight: 520)
        }
        .defaultSize(width: 960, height: 700)

        MenuBarExtra {
            MenuBarView().environment(store)
        } label: {
            MenuBarLabel(level: store.snapshot.level.level)
        }
        .menuBarExtraStyle(.window)
    }
}

extension Notification.Name {
    static let openMainWindow = Notification.Name("ProkachkaOpenMainWindow")
}

/// Значок в строке меню. Он живёт с первой секунды, поэтому через него окно открывается при запуске
/// и по щелчку в Dock — даже если macOS запомнила, что окно в прошлый раз закрыли.
struct MenuBarLabel: View {
    let level: Int
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("\(Image(systemName: "bolt.fill")) \(level)")
            .task { openWindow(id: "main") }
            .onReceive(NotificationCenter.default.publisher(for: .openMainWindow)) { _ in
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in SyncServer.shared.start() }
        // ⌥Пробел — быстрая запись из любого приложения.
        hotKey = HotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)) {
            Task { @MainActor in QuickEntryController.shared.toggle() }
        }
        if hotKey == nil {
            Task { @MainActor in
                EventStore.shared.problem = "Не удалось занять ⌥ Пробел: сочетание уже использует другое приложение. Запись доступна из строки меню."
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { NotificationCenter.default.post(name: .openMainWindow, object: nil) }
        return true
    }

    /// Окно закрыли — приложение остаётся в строке меню и слушает ⌥ Пробел.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
