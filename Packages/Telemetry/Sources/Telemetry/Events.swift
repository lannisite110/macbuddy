import Foundation

public enum PerfEventKind: String, Codable, Sendable {
    case coldStart
    case hotkeyToVisible
    case firstKeystroke
}

public struct PerfEvent: Codable, Equatable, Sendable {
    public let kind: PerfEventKind
    public let durationMs: Double
    public let timestamp: Date

    public init(kind: PerfEventKind, durationMs: Double, timestamp: Date = Date()) {
        self.kind = kind
        self.durationMs = durationMs
        self.timestamp = timestamp
    }
}
