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
            Text("\(Image(systemName: "bolt.fill")) \(store.snapshot.level.level)")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
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

    /// Окно закрыли — приложение остаётся в строке меню и слушает ⌥ Пробел.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
