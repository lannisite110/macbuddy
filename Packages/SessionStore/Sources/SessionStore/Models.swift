import Foundation

public enum SessionOrigin: String, Codable, Sendable {
    case chat
    case work
    case code
}

public struct SessionMetadata: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var updatedAt: Date
    public var origin: SessionOrigin

    public init(id: UUID = UUID(), title: String, updatedAt: Date = Date(), origin: SessionOrigin = .chat) {
        self.id = id
        self.title = title
        self.updatedAt = updatedAt
        self.origin = origin
    }
}
