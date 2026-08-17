import Foundation

public enum WorkflowStepKind: String, Codable, Sendable {
    case chatPrompt
    case workAction
    case codePrompt
}

public struct WorkflowStep: Codable, Equatable, Sendable {
    public let kind: WorkflowStepKind
    public let value: String

    public init(kind: WorkflowStepKind, value: String) {
        self.kind = kind
        self.value = value
    }
}

public struct WorkflowTemplate: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let steps: [WorkflowStep]

    public init(id: String, name: String, description: String, steps: [WorkflowStep]) {
        self.id = id
        self.name = name
        self.description = description
        self.steps = steps
    }
}

public enum WorkflowCatalog {
    public static let builtIn: [WorkflowTemplate] = [
        WorkflowTemplate(
            id: "quick-summarize",
            name: "Quick Summarize",
            description: "Summarize selected text via work assistant.",
            steps: [WorkflowStep(kind: .workAction, value: "summarize")]
        ),
        WorkflowTemplate(
            id: "meeting-notes",
            name: "Meeting Notes",
            description: "Turn selection into structured meeting notes.",
            steps: [WorkflowStep(kind: .workAction, value: "meetingNotes")]
        ),
        WorkflowTemplate(
            id: "code-review",
            name: "Code Review",
            description: "Review @file changes in the open workspace.",
            steps: [WorkflowStep(kind: .codePrompt, value: "Review @README.md for issues and suggest improvements.")]
        ),
        WorkflowTemplate(
            id: "chat-then-code",
            name: "Plan then Patch",
            description: "Ask for a plan in chat, then propose a code patch.",
            steps: [
                WorkflowStep(kind: .chatPrompt, value: "Outline the smallest change to implement this feature."),
                WorkflowStep(kind: .codePrompt, value: "Implement the plan with minimal diff."),
            ]
        ),
    ]

    public static func template(id: String) -> WorkflowTemplate? {
        builtIn.first { $0.id == id }
    }
}
