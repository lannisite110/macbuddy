import AppKit
import SwiftUI
import Telemetry

final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class ChatWindowController {
    static let shared = ChatWindowController()

    private var panel: KeyPanel?
    private var showStartedAt: CFAbsoluteTime?

    func show(focusComposer: @escaping () -> Void) {
        if panel == nil {
            let content = NSHostingController(
                rootView: ChatPanelView(onComposerReady: focusComposer)
                    .environmentObject(AppState.shared)
            )
            let panel = KeyPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
                styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.title = "MacBuddy"
            panel.titlebarAppearsTransparent = true
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentViewController = content
            panel.center()
            self.panel = panel
        }
        showStartedAt = CFAbsoluteTimeGetCurrent()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggle(focusComposer: @escaping () -> Void, fromHotkey: Bool = false) {
        if panel?.isVisible == true {
            hide()
        } else {
            show(focusComposer: focusComposer)
            if fromHotkey {
                DispatchQueue.main.async { [weak self] in
                    self?.recordHotkeyVisible(telemetry: AppState.shared.telemetry)
                }
            }
        }
    }

    func recordHotkeyVisible(telemetry: Telemetry) {
        guard let start = showStartedAt else { return }
        let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000
        try? telemetry.record(PerfEvent(kind: .hotkeyToVisible, durationMs: ms))
    }
}
