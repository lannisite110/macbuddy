import Foundation

public struct IndexRecord: Codable, Equatable, Sendable {
    public let relativePath: String
    public let modificationTime: TimeInterval

    public init(relativePath: String, modificationTime: TimeInterval) {
        self.relativePath = relativePath
        self.modificationTime = modificationTime
    }
}

public struct IncrementalIndex: Codable, Sendable {
    public var workspacePath: String
    public var records: [IndexRecord]

    public init(workspacePath: String, records: [IndexRecord] = []) {
        self.workspacePath = workspacePath
        self.records = records
    }

    public static func load(from url: URL) -> IncrementalIndex? {
        guard let data = try? Data(contentsOf: url),
              let index = try? JSONDecoder().decode(IncrementalIndex.self, from: data)
        else { return nil }
        return index
    }

    public func save(to url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(self)
        try data.write(to: url, options: .atomic)
    }

    public mutating func merge(with scanned: [WorkspaceEntry]) -> (unchanged: Int, updated: Int) {
        let oldMap = Dictionary(uniqueKeysWithValues: records.map { ($0.relativePath, $0.modificationTime) })
        var unchanged = 0
        var updated = 0
        records = scanned.map { entry in
            let mtime = entry.modificationDate.timeIntervalSince1970
            if let prev = oldMap[entry.relativePath], abs(prev - mtime) < 0.001 {
                unchanged += 1
            } else {
                updated += 1
            }
            return IndexRecord(relativePath: entry.relativePath, modificationTime: mtime)
        }
        return (unchanged, updated)
    }
}

public enum IncrementalIndexStore {
    public static func indexURL(for workspace: URL, storageDirectory: URL) -> URL {
        let hash = workspace.path.data(using: .utf8)?.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_") ?? "default"
        return storageDirectory.appendingPathComponent("index-\(hash).json")
    }

    public static func scan(workspace: URL, storageDirectory: URL, enabled: Bool) throws -> ([WorkspaceEntry], IncrementalIndexStats) {
        let fresh = try WorkspaceScanner.scan(workspace: workspace)
        guard enabled else {
            return (fresh, IncrementalIndexStats(enabled: false, unchanged: 0, updated: fresh.count))
        }
        let url = indexURL(for: workspace, storageDirectory: storageDirectory)
        var index = IncrementalIndex.load(from: url) ?? IncrementalIndex(workspacePath: workspace.path)
        index.workspacePath = workspace.path
        let stats = index.merge(with: fresh)
        try index.save(to: url)
        return (fresh, IncrementalIndexStats(enabled: true, unchanged: stats.unchanged, updated: stats.updated))
    }
}

public struct IncrementalIndexStats: Sendable {
    public let enabled: Bool
    public let unchanged: Int
    public let updated: Int
}
