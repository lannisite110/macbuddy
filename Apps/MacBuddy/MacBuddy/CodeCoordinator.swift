import AppKit
import CodeEngine
import Foundation
import LLMClient
import SessionStore
import SettingsStore

@MainActor
final class CodeCoordinator: ObservableObject {
    static let shared = CodeCoordinator()

    @Published var isWorkspaceOpen = false
    @Published var workspaceName: String?
    @Published var isBusy = false
    @Published var activePreview: PatchPreview?
    @Published var errorMessage: String?
    @Published var gitOutput: String?

    private var engine: CodeEngine?
    private var idleTask: Task<Void, Never>?
    private let settingsStore = SettingsStore()

    private init() {}

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in await self.openWorkspace(url) }
        }
    }

    func openWorkspace(_ url: URL) async {
        errorMessage = nil
        let engine = engine ?? CodeEngine()
        self.engine = engine
        do {
            try await engine.openWorkspace(url)
            isWorkspaceOpen = true
            workspaceName = url.lastPathComponent
            settingsStore.saveLastWorkspacePath(url.path)
            scheduleIdleClose()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func closeWorkspace() {
        idleTask?.cancel()
        Task {
            await engine?.closeWorkspace()
        }
        engine = nil
        isWorkspaceOpen = false
        workspaceName = nil
        activePreview = nil
    }

    func handleCodeRequest(_ prompt: String) {
        guard isWorkspaceOpen else {
            errorMessage = "Open a workspace folder first."
            return
        }
        idleTask?.cancel()
        scheduleIdleClose()
        isBusy = true
        errorMessage = nil
        Task {
            defer { isBusy = false }
            guard let engine else { return }
            do {
                let settings = settingsStore.loadModelSettings()
                let config = LLMConfiguration(baseURL: settings.baseURL, model: settings.model)
                let preview = try await engine.proposePatch(
                    prompt: prompt,
                    configuration: config,
                    apiKey: settingsStore.loadAPIKey()
                )
                activePreview = preview
                persistCodeSession(prompt: prompt, preview: preview)
            } catch {
                errorMessage = friendly(error)
            }
        }
    }

    func applyPreview(_ preview: PatchPreview) {
        Task {
            do {
                try await engine?.apply(preview: preview)
                activePreview = nil
                scheduleIdleClose()
            } catch {
                errorMessage = friendly(error)
            }
        }
    }

    func explainGitDiff() {
        runGitAction { try await $0.explainGitDiff() }
    }

    func explainGitLog() {
        runGitAction { try await $0.explainGitLog() }
    }

    private func runGitAction(_ action: @escaping (CodeEngine) async throws -> String) {
        guard isWorkspaceOpen, let engine else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                gitOutput = try await action(engine)
            } catch {
                errorMessage = friendly(error)
            }
        }
    }

    private func scheduleIdleClose() {
        idleTask?.cancel()
        idleTask = Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            if !Task.isCancelled, !isBusy, activePreview == nil {
                closeWorkspace()
            }
        }
    }

    private func persistCodeSession(prompt: String, preview: PatchPreview) {
        let session = SessionMetadata(title: "Code: \(prompt.prefix(30))", origin: .code)
        try? AppState.shared.sessionStore.insertSession(session)
        guard let sessionId = AppState.shared.sessionStore.lastInsertedSessionId else { return }
        _ = try? AppState.shared.sessionStore.insertMessage(sessionId: sessionId, role: "user", body: prompt)
        let diffText = preview.changes.map(\.unifiedDiff).joined(separator: "\n\n")
        _ = try? AppState.shared.sessionStore.insertMessage(sessionId: sessionId, role: "assistant", body: diffText)
        try? AppState.shared.sessionStore.touchSession(id: sessionId, title: session.title)
        AppState.shared.loadSessionMetadata()
    }

    private func friendly(_ error: Error) -> String {
        if case LLMClientError.httpStatus(let code, _) = error {
            return code == 401 ? "Invalid API key." : "Request failed (\(code))."
        }
        return String(describing: error)
    }
}
