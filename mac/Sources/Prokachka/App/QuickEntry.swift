import AppKit
import Carbon.HIToolbox
import SwiftUI
import ProkachkaCore

/// Глобальная клавиша через Carbon: не нужно разрешение «Универсальный доступ».
final class HotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let me = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, _, data in
            guard let data else { return noErr }
            let hotKey = Unmanaged<HotKey>.fromOpaque(data).takeUnretainedValue()
            DispatchQueue.main.async { hotKey.action() }
            return noErr
        }, 1, &spec, me, &handler)
        let id = EventHotKeyID(signature: OSType(0x50524B43), id: 1) // «PRKC»
        let registered = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
        guard installed == noErr, registered == noErr else { return nil }
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}

/// Панель как у Spotlight: появляется поверх всего, Esc или запись — закрывается.
final class QuickEntryPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) { close() }
}

@MainActor
final class QuickEntryController {
    static let shared = QuickEntryController()
    private var panel: QuickEntryPanel?

    func toggle() {
        if let panel, panel.isVisible { panel.close(); return }
        show()
    }

    private func show() {
        let panel = QuickEntryPanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 120),
                                    styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView], backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        let root = Composer(compact: true, autofocus: true) { [weak panel] _ in
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.9))
                panel?.close()
            }
        }
        .environment(EventStore.shared)
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .padding(.bottom, 14)
        .frame(width: 560)
        let host = NSHostingView(rootView: root)
        panel.contentView = host
        panel.setContentSize(host.fittingSize)
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: f.midX - panel.frame.width / 2, y: f.minY + f.height * 0.68))
        }
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
