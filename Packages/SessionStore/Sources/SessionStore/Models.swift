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

public enum MessageStatus: String, Codable, Sendable {
    case complete
    case cancelled
    case error
}

public struct StoredMessage: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let sessionId: UUID
    public let role: String
    public var body: String
    public let createdAt: Date
    public var status: MessageStatus

    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        role: String,
        body: String,
        createdAt: Date = Date(),
        status: MessageStatus = .complete
    ) {
        self.id = id
        self.sessionId = sessionId
        self.role = role
        self.body = body
        self.createdAt = createdAt
        self.status = status
    }
}
