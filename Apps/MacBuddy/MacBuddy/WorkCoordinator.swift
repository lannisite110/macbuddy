import Foundation
import LLMClient
import SessionStore
import SettingsStore
import WorkSkills

struct WorkResultPresentation: Identifiable {
    let id = UUID()
    let action: WorkAction
    let sourceText: String
    var resultText: String
}

@MainActor
final class WorkCoordinator: ObservableObject {
    static let shared = WorkCoordinator()

    @Published var isRunning = false
    @Published var activeResult: WorkResultPresentation?
    @Published var errorMessage: String?

    private var engine: WorkEngine?
    private var task: Task<Void, Never>?
    private let settingsStore = SettingsStore()

    private init() {}

    func runSelectionAction(_ action: WorkAction) {
        task?.cancel()
        task = Task {
            do {
                if !PermissionBroker.isAccessibilityTrusted() {
                    _ = PermissionBroker.requestAccessibility()
                    guard PermissionBroker.isAccessibilityTrusted() else {
                        errorMessage = "Accessibility permission required for selection actions."
                        return
                    }
                }
                let text = try SelectionReader.readSelectedText()
                await perform(action: action, input: text)
            } catch WorkSkillsError.accessibilityDenied {
                errorMessage = "Enable Accessibility for MacBuddy in System Settings."
            } catch WorkSkillsError.noSelection {
                errorMessage = "No text selected."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func perform(action: WorkAction, input: String) async {
        isRunning = true
        errorMessage = nil
        defer { isRunning = false }

        do {
            let settings = settingsStore.loadModelSettings()
            let config = LLMConfiguration(baseURL: settings.baseURL, model: settings.model)
            let engine = engine ?? WorkEngine()
            self.engine = engine
            let output = try await engine.run(
                action: action,
                input: input,
                configuration: config,
                apiKey: settingsStore.loadAPIKey()
            )
            activeResult = WorkResultPresentation(action: action, sourceText: input, resultText: output)
            persistWorkSession(action: action, input: input, output: output)
        } catch {
            errorMessage = friendlyError(error)
        }
    }

    func summarizeFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                do {
                    let text = try FileTextReader.readText(from: url)
                    await self.perform(action: .summarize, input: text)
                } catch WorkSkillsError.fileTooLarge {
                    self.errorMessage = "File too large (max \(FileTextReader.maxCharacters) characters)."
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func copyResult(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func replaceSelection(with text: String) {
        do {
            try SelectionReader.replaceSelectedText(text)
        } catch {
            copyResult(text)
            errorMessage = "Could not replace in place; copied to clipboard instead."
        }
    }

    func openAccessibilitySettings() {
        PermissionBroker.openAccessibilitySettings()
    }

    private func persistWorkSession(action: WorkAction, input: String, output: String) {
        let session = SessionMetadata(title: action.menuTitle, origin: .work)
        try? AppState.shared.sessionStore.insertSession(session)
        if let sessionId = AppState.shared.sessionStore.lastInsertedSessionId {
            _ = try? AppState.shared.sessionStore.insertMessage(sessionId: sessionId, role: "user", body: input)
            _ = try? AppState.shared.sessionStore.insertMessage(sessionId: sessionId, role: "assistant", body: output)
            try? AppState.shared.sessionStore.touchSession(id: sessionId, title: action.menuTitle)
            AppState.shared.loadSessionMetadata()
        }
    }

    private func friendlyError(_ error: Error) -> String {
        if case LLMClientError.httpStatus(let code, _) = error {
            return code == 401 ? "Invalid API key." : "Request failed (\(code))."
        }
        return error.localizedDescription
    }
}

import AppKit
