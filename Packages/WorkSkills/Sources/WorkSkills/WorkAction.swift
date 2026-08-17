import Foundation

public enum WorkAction: String, Codable, Sendable, CaseIterable {
    case summarize
    case rewrite
    case meetingNotes

    public var menuTitle: String {
        switch self {
        case .summarize: return "Summarize Selection"
        case .rewrite: return "Rewrite Selection"
        case .meetingNotes: return "Meeting Notes from Selection"
        }
    }
}

public enum WorkPrompts {
    public static func systemPrompt(for action: WorkAction) -> String {
        switch action {
        case .summarize:
            return "You summarize text clearly and concisely. Output only the summary."
        case .rewrite:
            return "You rewrite text to improve clarity and tone while preserving meaning. Output only the rewritten text."
        case .meetingNotes:
            return "You turn transcripts or rough notes into structured meeting notes with headings for Summary, Decisions, and Action Items. Output only the notes."
        }
    }

    public static func userPrompt(for action: WorkAction, text: String) -> String {
        switch action {
        case .summarize:
            return "Summarize the following:\n\n\(text)"
        case .rewrite:
            return "Rewrite the following:\n\n\(text)"
        case .meetingNotes:
            return "Create meeting notes from the following:\n\n\(text)"
        }
    }
}

public enum FileTextReader {
    public static let maxCharacters = 100_000

    public static func readText(from url: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw WorkSkillsError.notAFile
        }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else {
            throw WorkSkillsError.notAFile
        }
        if let size = values.fileSize, size > maxCharacters * 4 {
            throw WorkSkillsError.fileTooLarge
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        if text.count > maxCharacters {
            return String(text.prefix(maxCharacters))
        }
        return text
    }
}

public enum WorkSkillsError: Error, Equatable {
    case notAFile
    case fileTooLarge
    case emptyInput
    case accessibilityDenied
    case noSelection
}
