import Foundation

public enum CodeEngineError: Error, Equatable {
    case noWorkspace
    case fileNotFound(String)
    case fileTooLarge(String)
    case invalidPatch
    case applyFailed(String)
    case commandNotAllowed(String)
    case commandFailed(String)
    case gitFailed(String)
}

public struct PatchFileChange: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let relativePath: String
    public let oldContent: String
    public let newContent: String
    public let unifiedDiff: String

    public init(relativePath: String, oldContent: String, newContent: String, unifiedDiff: String) {
        self.id = UUID()
        self.relativePath = relativePath
        self.oldContent = oldContent
        self.newContent = newContent
        self.unifiedDiff = unifiedDiff
    }
}

public struct PatchPreview: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let summary: String
    public let changes: [PatchFileChange]

    public init(summary: String, changes: [PatchFileChange]) {
        self.id = UUID()
        self.summary = summary
        self.changes = changes
    }
}

public enum MentionParser {
    public static func extractMentions(from text: String) -> [String] {
        let pattern = "@([^\\s@]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[r])
        }
    }
}

public enum UnifiedDiff {
    public static func make(path: String, old: String, new: String) -> String {
        let oldLines = old.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let newLines = new.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var output = ["--- a/\(path)", "+++ b/\(path)"]
        output.append(contentsOf: diffLines(oldLines, newLines))
        return output.joined(separator: "\n")
    }

    private static func diffLines(_ old: [String], _ new: [String]) -> [String] {
        guard old != new else { return [" "] }
        var result: [String] = []
        let maxCount = max(old.count, new.count)
        for index in 0..<maxCount {
            let o = index < old.count ? old[index] : nil
            let n = index < new.count ? new[index] : nil
            if o == n { continue }
            if let o { result.append("-\(o)") }
            if let n { result.append("+\(n)") }
        }
        return result.isEmpty ? [" "] : result
    }
}

public enum IgnoreRules {
    public static let defaults: [String] = [
        ".git", "node_modules", "DerivedData", ".build", "build", "dist", "__pycache__", ".DS_Store",
    ]

    public static func shouldIgnore(relativePath: String, workspacePatterns: [String]) -> Bool {
        let parts = relativePath.split(separator: "/").map(String.init)
        for part in parts {
            if defaults.contains(part) { return true }
        }
        for pattern in workspacePatterns {
            if matches(pattern: pattern, path: relativePath) { return true }
        }
        return false
    }

    public static func loadGitignore(from workspace: URL) -> [String] {
        let url = workspace.appendingPathComponent(".gitignore")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { return nil }
            return trimmed
        }
    }

    private static func matches(pattern: String, path: String) -> Bool {
        if pattern.hasSuffix("/") {
            return path.contains(String(pattern.dropLast()))
        }
        if pattern.hasPrefix("*") {
            return path.hasSuffix(String(pattern.dropFirst()))
        }
        return path == pattern || path.hasSuffix("/\(pattern)") || path.contains("/\(pattern)/")
    }
}

public struct WorkspaceEntry: Sendable {
    public let relativePath: String
    public let modificationDate: Date
}

public enum WorkspaceScanner {
    public static func scan(workspace: URL) throws -> [WorkspaceEntry] {
        let patterns = IgnoreRules.loadGitignore(from: workspace)
        var entries: [WorkspaceEntry] = []
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: workspace, includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        for case let fileURL as URL in enumerator {
            let rel = fileURL.path.replacingOccurrences(of: workspace.path + "/", with: "")
            if IgnoreRules.shouldIgnore(relativePath: rel, workspacePatterns: patterns) {
                if fileURL.hasDirectoryPath { enumerator.skipDescendants() }
                continue
            }
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])
            guard values.isRegularFile == true else { continue }
            entries.append(WorkspaceEntry(relativePath: rel, modificationDate: values.contentModificationDate ?? .distantPast))
        }
        return entries.sorted { $0.relativePath < $1.relativePath }
    }
}

public enum FileReader {
    public static let maxBytes = 256 * 1024

    public static func read(relativePath: String, workspace: URL) throws -> String {
        let url = workspace.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CodeEngineError.fileNotFound(relativePath)
        }
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attrs[.size] as? NSNumber, size.intValue > maxBytes {
            throw CodeEngineError.fileTooLarge(relativePath)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

public enum PatchParser {
    /// Parses LLM output blocks: FILE: path\n```...\n```
    public static func parse(_ response: String) -> [(path: String, content: String)] {
        var results: [(String, String)] = []
        let lines = response.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var index = 0
        while index < lines.count {
            let line = lines[index]
            if line.hasPrefix("FILE:") {
                let path = line.replacingOccurrences(of: "FILE:", with: "").trimmingCharacters(in: .whitespaces)
                index += 1
                while index < lines.count, !lines[index].hasPrefix("```") { index += 1 }
                if index >= lines.count { break }
                index += 1
                var contentLines: [String] = []
                while index < lines.count, !lines[index].hasPrefix("```") {
                    contentLines.append(lines[index])
                    index += 1
                }
                results.append((path, contentLines.joined(separator: "\n")))
            }
            index += 1
        }
        return results
    }
}

public enum GitReader {
    public static func diff(workspace: URL) throws -> String {
        try runGit(["diff"], workspace: workspace)
    }

    public static func log(workspace: URL, limit: Int = 20) throws -> String {
        try runGit(["log", "-n", "\(limit)", "--oneline"], workspace: workspace)
    }

    private static func runGit(_ args: [String], workspace: URL) throws -> String {
        let result = try CommandRunner.run(executable: "git", arguments: args, workspace: workspace)
        return result.stdout
    }
}

public enum CommandRunner {
    public static let allowlist: Set<String> = ["git", "ls", "rg"]
    public static let timeoutSeconds: TimeInterval = 10

    public static func run(executable: String, arguments: [String], workspace: URL) throws -> (stdout: String, stderr: String) {
        let name = (executable as NSString).lastPathComponent
        guard allowlist.contains(name) else {
            throw CodeEngineError.commandNotAllowed(name)
        }
        for arg in arguments {
            if arg.contains("curl") || arg.contains("rm") {
                throw CodeEngineError.commandNotAllowed(arg)
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/\(name)")
        if !FileManager.default.fileExists(atPath: process.executableURL!.path) {
            process.executableURL = URL(fileURLWithPath: "/bin/\(name)")
        }
        process.arguments = arguments
        process.currentDirectoryURL = workspace
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/usr/bin:/bin:/usr/local/bin"
        process.environment = env

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err

        try process.run()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds) {
            if process.isRunning { process.terminate() }
            group.leave()
        }
        process.waitUntilExit()
        group.wait()

        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw CodeEngineError.commandFailed(stderr.isEmpty ? stdout : stderr)
        }
        return (stdout, stderr)
    }
}

public enum PatchApplier {
    public static func apply(change: PatchFileChange, workspace: URL) throws {
        let url = workspace.appendingPathComponent(change.relativePath)
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        do {
            try change.newContent.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            try change.oldContent.write(to: url, atomically: true, encoding: .utf8)
            throw CodeEngineError.applyFailed(change.relativePath)
        }
    }
}
