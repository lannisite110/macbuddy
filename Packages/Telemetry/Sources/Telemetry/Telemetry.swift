import Foundation

public struct Telemetry {
    private let fileURL: URL

    public init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("perf.jsonl")
    }

    public func record(_ event: PerfEvent) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        guard let line = String(data: data, encoding: .utf8) else { return }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data((line + "\n").utf8))
        } else {
            try (line + "\n").write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    public func recentColdStarts(limit: Int) throws -> [PerfEvent] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let events: [PerfEvent] = text.split(separator: "\n").compactMap { line in
            guard let data = String(line).data(using: .utf8) else { return nil }
            return try? decoder.decode(PerfEvent.self, from: data)
        }
        return Array(events.filter { $0.kind == .coldStart }.suffix(limit))
    }
}
