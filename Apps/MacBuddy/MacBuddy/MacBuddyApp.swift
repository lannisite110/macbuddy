import AppKit
import SwiftUI

@main
struct MacBuddyApp: App {
    @StateObject private var appState = AppState.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let hotkeyManager = HotkeyManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppState.shared.loadSessionMetadata()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "MB"
        let menu = NSMenu()
        menu.addItem(withTitle: "Toggle Panel", action: #selector(togglePanel), keyEquivalent: "")
        menu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit MacBuddy", action: #selector(quit), keyEquivalent: "q")
        statusItem?.menu = menu

        ChatWindowController.shared.show(focusComposer: {})

        hotkeyManager.register(HotkeyManager.defaultHotkey) {
            ChatWindowController.shared.toggle(focusComposer: {})
            ChatWindowController.shared.recordHotkeyVisible(telemetry: AppState.shared.telemetry)
        }
    }

    @objc private func togglePanel() {
        ChatWindowController.shared.toggle(focusComposer: {})
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
