import Foundation
import SettingsStore
import WorkflowTemplates
import WorkSkills

@MainActor
final class WorkflowCoordinator: ObservableObject {
    static let shared = WorkflowCoordinator()

    @Published var isRunning = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    private let settingsStore = SettingsStore()

    private init() {}

    func run(_ template: WorkflowTemplate) {
        guard !isRunning else { return }
        isRunning = true
        errorMessage = nil
        statusMessage = "Running \(template.name)…"
        Task {
            defer {
                isRunning = false
                statusMessage = nil
            }
            for (index, step) in template.steps.enumerated() {
                statusMessage = "\(template.name): step \(index + 1)/\(template.steps.count)"
                switch step.kind {
                case .workAction:
                    guard let action = WorkAction(rawValue: step.value) else { continue }
                    WorkCoordinator.shared.runSelectionAction(action)
                    while WorkCoordinator.shared.isRunning {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                    if WorkCoordinator.shared.errorMessage != nil {
                        errorMessage = WorkCoordinator.shared.errorMessage
                        return
                    }
                case .codePrompt:
                    guard CodeCoordinator.shared.isWorkspaceOpen else {
                        errorMessage = "Open a workspace for code workflow steps."
                        return
                    }
                    guard settingsStore.consumeQuota() else {
                        errorMessage = "Monthly quota exceeded."
                        return
                    }
                    CodeCoordinator.shared.handleCodeRequest(step.value)
                    while CodeCoordinator.shared.isBusy {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                    if CodeCoordinator.shared.errorMessage != nil {
                        errorMessage = CodeCoordinator.shared.errorMessage
                        return
                    }
                case .chatPrompt:
                    guard settingsStore.consumeQuota() else {
                        errorMessage = "Monthly quota exceeded."
                        return
                    }
                    NotificationCenter.default.post(name: .workflowChatPrompt, object: step.value)
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }
            }
            statusMessage = "Workflow finished."
        }
    }
}

extension Notification.Name {
    static let workflowChatPrompt = Notification.Name("com.macbuddy.workflowChatPrompt")
}
