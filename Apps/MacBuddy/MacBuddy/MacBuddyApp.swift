import AppKit
import SwiftUI
import WorkSkills

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
        NSApp.servicesProvider = ServicesController.shared
        NSUpdateDynamicServices()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "MB"

        let menu = NSMenu()
        menu.addItem(withTitle: "Toggle Panel", action: #selector(togglePanel), keyEquivalent: "")

        let workMenu = NSMenu()
        workMenu.addItem(withTitle: WorkAction.summarize.menuTitle, action: #selector(summarizeSelection), keyEquivalent: "")
        workMenu.addItem(withTitle: WorkAction.rewrite.menuTitle, action: #selector(rewriteSelection), keyEquivalent: "")
        workMenu.addItem(withTitle: WorkAction.meetingNotes.menuTitle, action: #selector(meetingNotesSelection), keyEquivalent: "")
        workMenu.addItem(.separator())
        workMenu.addItem(withTitle: "Summarize File…", action: #selector(summarizeFile), keyEquivalent: "")
        for item in workMenu.items { item.target = self }

        let workRoot = NSMenuItem(title: "Work", action: nil, keyEquivalent: "")
        menu.setSubmenu(workMenu, for: workRoot)
        menu.addItem(workRoot)

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

    @objc private func summarizeSelection() {
        ChatWindowController.shared.show(focusComposer: {})
        WorkCoordinator.shared.runSelectionAction(.summarize)
    }

    @objc private func rewriteSelection() {
        ChatWindowController.shared.show(focusComposer: {})
        WorkCoordinator.shared.runSelectionAction(.rewrite)
    }

    @objc private func meetingNotesSelection() {
        ChatWindowController.shared.show(focusComposer: {})
        WorkCoordinator.shared.runSelectionAction(.meetingNotes)
    }

    @objc private func summarizeFile() {
        ChatWindowController.shared.show(focusComposer: {})
        WorkCoordinator.shared.summarizeFile()
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
