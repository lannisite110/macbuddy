import Foundation
import LLMClient

public actor CodeEngine {
    private var workspaceURL: URL?
    private var entries: [WorkspaceEntry] = []
    private var indexStats: IncrementalIndexStats?
    private var llmClient: LLMClient?

    public init() {}

    public var isOpen: Bool { workspaceURL != nil }
    public var workspacePath: String? { workspaceURL?.path }
    public var filePaths: [String] { entries.map(\.relativePath) }
    public var lastIndexStats: IncrementalIndexStats? { indexStats }

    public func openWorkspace(_ url: URL, storageDirectory: URL, incrementalIndexEnabled: Bool) async throws {
        workspaceURL = url
        let result = try IncrementalIndexStore.scan(
            workspace: url,
            storageDirectory: storageDirectory,
            enabled: incrementalIndexEnabled
        )
        entries = result.0
        indexStats = result.1
    }

    public func closeWorkspace() {
        workspaceURL = nil
        entries = []
        indexStats = nil
    }

    public func resolveMentions(in text: String) -> [String] {
        let mentions = MentionParser.extractMentions(from: text)
        let paths = entries.map(\.relativePath)
        return mentions.filter { mention in
            paths.contains(mention) || paths.contains(where: { $0.hasSuffix(mention) || $0.hasSuffix("/\(mention)") })
        }
    }

    public func proposePatch(
        prompt: String,
        configuration: LLMConfiguration,
        apiKey: String?
    ) async throws -> PatchPreview {
        guard let workspace = workspaceURL else { throw CodeEngineError.noWorkspace }

        var paths = MentionParser.extractMentions(from: prompt)
        if paths.isEmpty, let firstSwift = entries.first(where: { $0.relativePath.hasSuffix(".swift") }) {
            paths = [firstSwift.relativePath]
        }

        var fileContexts: [String] = []
        for path in paths {
            do {
                let content = try FileReader.read(relativePath: path, workspace: workspace)
                fileContexts.append("FILE: \(path)\n```\n\(content)\n```")
            } catch CodeEngineError.fileTooLarge(let p) {
                fileContexts.append("FILE: \(p) [skipped: too large]")
            } catch {
                continue
            }
        }

        let system = """
        You are a coding assistant. When editing files respond ONLY with one or more blocks:
        FILE: relative/path
        ```
        full new file content
        ```
        Do not include explanations outside these blocks.
        """
        let user = """
        Workspace files available: \(entries.prefix(200).map(\.relativePath).joined(separator: ", "))

        Context files:
        \(fileContexts.joined(separator: "\n\n"))

        Request: \(prompt)
        """

        let client = try client(configuration: configuration, apiKey: apiKey)
        let stream = await client.streamCompletion(messages: [
            ChatMessage(role: "system", content: system),
            ChatMessage(role: "user", content: user),
        ])
        var response = ""
        for try await token in stream { response += token }

        let parsed = PatchParser.parse(response)
        guard !parsed.isEmpty else { throw CodeEngineError.invalidPatch }

        var changes: [PatchFileChange] = []
        for item in parsed {
            let relative = try WorkspacePath.normalizedRelativePath(item.path, workspace: workspace)
            let old = (try? FileReader.read(relativePath: relative, workspace: workspace)) ?? ""
            let diff = UnifiedDiff.make(path: relative, old: old, new: item.content)
            if old != item.content {
                changes.append(PatchFileChange(relativePath: relative, oldContent: old, newContent: item.content, unifiedDiff: diff))
            }
        }
        guard !changes.isEmpty else { throw CodeEngineError.invalidPatch }
        return PatchPreview(summary: prompt, changes: changes)
    }

    public func apply(preview: PatchPreview) throws {
        guard let workspace = workspaceURL else { throw CodeEngineError.noWorkspace }
        for change in preview.changes {
            try PatchApplier.apply(change: change, workspace: workspace)
        }
        entries = try WorkspaceScanner.scan(workspace: workspace)
    }

    public func explainGitDiff() throws -> String {
        guard let workspace = workspaceURL else { throw CodeEngineError.noWorkspace }
        return try GitReader.diff(workspace: workspace)
    }

    public func explainGitLog() throws -> String {
        guard let workspace = workspaceURL else { throw CodeEngineError.noWorkspace }
        return try GitReader.log(workspace: workspace)
    }

    private func client(configuration: LLMConfiguration, apiKey: String?) throws -> LLMClient {
        if let llmClient { return llmClient }
        let created = try LLMClient(configuration: configuration, apiKey: apiKey)
        llmClient = created
        return created
    }
}
