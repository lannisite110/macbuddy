import AppKit
import SwiftUI
import WorkSkills
import WorkflowTemplates

@main
struct MacBuddyApp: App {
    @StateObject private var appState = AppState.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        LaunchTiming.markProcessStart()
    }

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

        let codeMenu = NSMenu()
        codeMenu.addItem(withTitle: "Open Workspace…", action: #selector(openWorkspace), keyEquivalent: "")
        codeMenu.addItem(withTitle: "Close Workspace", action: #selector(closeWorkspace), keyEquivalent: "")
        codeMenu.addItem(.separator())
        codeMenu.addItem(withTitle: "Explain Git Diff", action: #selector(explainGitDiff), keyEquivalent: "")
        codeMenu.addItem(withTitle: "Explain Git Log", action: #selector(explainGitLog), keyEquivalent: "")
        for item in codeMenu.items { item.target = self }

        let codeRoot = NSMenuItem(title: "Code", action: nil, keyEquivalent: "")
        menu.setSubmenu(codeMenu, for: codeRoot)
        menu.addItem(codeRoot)

        let workflowMenu = NSMenu()
        for template in WorkflowCatalog.builtIn {
            let item = NSMenuItem(title: template.name, action: #selector(runWorkflow(_:)), keyEquivalent: "")
            item.representedObject = template.id
            item.target = self
            workflowMenu.addItem(item)
        }
        let workflowRoot = NSMenuItem(title: "Workflows", action: nil, keyEquivalent: "")
        menu.setSubmenu(workflowMenu, for: workflowRoot)
        menu.addItem(workflowRoot)

        menu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit MacBuddy", action: #selector(quit), keyEquivalent: "q")
        statusItem?.menu = menu

        if !BenchMode.isEnabled {
            ChatWindowController.shared.show(focusComposer: {})
        }

        hotkeyManager.register(HotkeyManager.defaultHotkey) {
            ChatWindowController.shared.toggle(focusComposer: {}, fromHotkey: true)
        }

        if BenchMode.simulateHotkey {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                ChatWindowController.shared.toggle(focusComposer: {}, fromHotkey: true)
            }
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

    @objc private func openWorkspace() {
        ChatWindowController.shared.show(focusComposer: {})
        CodeCoordinator.shared.openFolder()
    }

    @objc private func closeWorkspace() {
        CodeCoordinator.shared.closeWorkspace()
    }

    @objc private func explainGitDiff() {
        ChatWindowController.shared.show(focusComposer: {})
        CodeCoordinator.shared.explainGitDiff()
    }

    @objc private func explainGitLog() {
        ChatWindowController.shared.show(focusComposer: {})
        CodeCoordinator.shared.explainGitLog()
    }

    @objc private func runWorkflow(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let template = WorkflowCatalog.template(id: id) else { return }
        ChatWindowController.shared.show(focusComposer: {})
        WorkflowCoordinator.shared.run(template)
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
