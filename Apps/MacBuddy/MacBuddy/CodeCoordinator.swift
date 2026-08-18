import AppKit
import CodeEngine
import CodeSidecarClient
import Foundation
import LLMClient
import SessionStore
import SettingsStore
import SidecarIPC

@MainActor
final class CodeCoordinator: ObservableObject {
    static let shared = CodeCoordinator()

    @Published var isWorkspaceOpen = false
    @Published var workspaceName: String?
    @Published var isBusy = false
    @Published var activePreview: PatchPreview?
    @Published var errorMessage: String?
    @Published var gitOutput: String?
    @Published var indexStatus: String?
    @Published var sidecarIssue: SidecarIssue?

    private var sidecar: CodeSidecarClient?
    private var idleTask: Task<Void, Never>?
    private var lastRetry: CodeRetry?
    private let settingsStore = SettingsStore()

    private enum CodeRetry {
        case open(URL)
        case patch(String)
        case apply(PatchPreview)
        case gitDiff
        case gitLog
    }

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
        sidecarIssue = nil
        lastRetry = .open(url)
        let sidecar = sidecar ?? CodeSidecarClient()
        self.sidecar = sidecar
        do {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("MacBuddy", isDirectory: true)
            let features = settingsStore.loadFeatureSettings()
            let result = try await sidecar.openWorkspace(
                url,
                storageDirectory: support.appendingPathComponent("Index", isDirectory: true),
                incrementalIndexEnabled: features.incrementalIndexEnabled
            )
            isWorkspaceOpen = true
            workspaceName = result.workspaceName
            settingsStore.saveLastWorkspacePath(url.path)
            if result.stats.enabled {
                indexStatus = "Index: \(result.stats.unchanged) unchanged, \(result.stats.updated) updated"
            } else {
                indexStatus = nil
            }
            scheduleIdleClose()
        } catch {
            recordFailure(error)
        }
    }

    func closeWorkspace() {
        idleTask?.cancel()
        Task {
            await sidecar?.closeWorkspace()
        }
        sidecar = nil
        isWorkspaceOpen = false
        workspaceName = nil
        activePreview = nil
        indexStatus = nil
        lastRetry = nil
        sidecarIssue = nil
    }

    func handleCodeRequest(_ prompt: String) {
        guard isWorkspaceOpen else {
            errorMessage = "Open a workspace folder first."
            return
        }
        guard settingsStore.consumeQuota() else {
            errorMessage = "Monthly quota exceeded."
            return
        }
        idleTask?.cancel()
        scheduleIdleClose()
        isBusy = true
        errorMessage = nil
        sidecarIssue = nil
        lastRetry = .patch(prompt)
        Task {
            defer { isBusy = false }
            guard let sidecar else { return }
            do {
                let settings = settingsStore.loadModelSettings()
                let config = LLMConfiguration(baseURL: settings.baseURL, model: settings.model)
                let preview = try await sidecar.proposePatch(
                    prompt: prompt,
                    configuration: config,
                    apiKey: settingsStore.loadAPIKey()
                )
                activePreview = preview
                persistCodeSession(prompt: prompt, preview: preview)
            } catch {
                recordFailure(error)
            }
        }
    }

    func applyPreview(_ preview: PatchPreview) {
        lastRetry = .apply(preview)
        sidecarIssue = nil
        Task {
            do {
                try await sidecar?.apply(preview: preview)
                activePreview = nil
                scheduleIdleClose()
            } catch {
                recordFailure(error)
            }
        }
    }

    func explainGitDiff() {
        lastRetry = .gitDiff
        runGitAction { try await $0.explainGitDiff() }
    }

    func explainGitLog() {
        lastRetry = .gitLog
        runGitAction { try await $0.explainGitLog() }
    }

    private func runGitAction(_ action: @escaping (CodeSidecarClient) async throws -> String) {
        guard isWorkspaceOpen, let sidecar else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                gitOutput = try await action(sidecar)
            } catch {
                recordFailure(error)
            }
        }
    }

    func retrySidecar() {
        guard let lastRetry else { return }
        sidecarIssue = nil
        errorMessage = nil
        Task {
            await sidecar?.reset()
            switch lastRetry {
            case let .open(url):
                await openWorkspace(url)
            case let .patch(prompt):
                handleCodeRequest(prompt)
            case let .apply(preview):
                applyPreview(preview)
            case .gitDiff:
                explainGitDiff()
            case .gitLog:
                explainGitLog()
            }
        }
    }

    private func recordFailure(_ error: Error) {
        errorMessage = SidecarRecovery.message(sidecarName: "Code", error: error)
        if SidecarRecovery.isRecoverable(error) {
            sidecarIssue = SidecarIssue(sidecarName: "Code", message: errorMessage ?? "", canRetry: true)
        } else if (error as? SidecarLaunchError) == .helperMissing {
            sidecarIssue = SidecarIssue(sidecarName: "Code", message: errorMessage ?? "", canRetry: false)
        } else {
            sidecarIssue = nil
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
}
