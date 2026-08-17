import Foundation
import LLMClient

public enum SidecarRequest: Codable, Sendable {
    case ping
    case complete(requestId: String, configuration: LLMConfiguration, apiKey: String?, messages: [ChatMessage])
    case cancel(requestId: String)

    private enum CodingKeys: String, CodingKey { case type, requestId, configuration, apiKey, messages }

    private enum Kind: String, Codable { case ping, complete, cancel }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .ping:
            self = .ping
        case .complete:
            self = try .complete(
                requestId: container.decode(String.self, forKey: .requestId),
                configuration: container.decode(LLMConfiguration.self, forKey: .configuration),
                apiKey: container.decodeIfPresent(String.self, forKey: .apiKey),
                messages: container.decode([ChatMessage].self, forKey: .messages)
            )
        case .cancel:
            self = try .cancel(requestId: container.decode(String.self, forKey: .requestId))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .ping:
            try container.encode(Kind.ping, forKey: .type)
        case let .complete(requestId, configuration, apiKey, messages):
            try container.encode(Kind.complete, forKey: .type)
            try container.encode(requestId, forKey: .requestId)
            try container.encode(configuration, forKey: .configuration)
            try container.encodeIfPresent(apiKey, forKey: .apiKey)
            try container.encode(messages, forKey: .messages)
        case let .cancel(requestId):
            try container.encode(Kind.cancel, forKey: .type)
            try container.encode(requestId, forKey: .requestId)
        }
    }
}

public enum SidecarEvent: Codable, Sendable, Equatable {
    case ready
    case pong(latencyMs: Double)
    case token(requestId: String, text: String)
    case done(requestId: String)
    case error(requestId: String?, message: String)

    private enum CodingKeys: String, CodingKey { case type, requestId, text, latencyMs, message }

    private enum Kind: String, Codable { case ready, pong, token, done, error }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .ready:
            self = .ready
        case .pong:
            self = try .pong(latencyMs: container.decode(Double.self, forKey: .latencyMs))
        case .token:
            self = try .token(
                requestId: container.decode(String.self, forKey: .requestId),
                text: container.decode(String.self, forKey: .text)
            )
        case .done:
            self = try .done(requestId: container.decode(String.self, forKey: .requestId))
        case .error:
            self = try .error(
                requestId: container.decodeIfPresent(String.self, forKey: .requestId),
                message: container.decode(String.self, forKey: .message)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .ready:
            try container.encode(Kind.ready, forKey: .type)
        case let .pong(latencyMs):
            try container.encode(Kind.pong, forKey: .type)
            try container.encode(latencyMs, forKey: .latencyMs)
        case let .token(requestId, text):
            try container.encode(Kind.token, forKey: .type)
            try container.encode(requestId, forKey: .requestId)
            try container.encode(text, forKey: .text)
        case let .done(requestId):
            try container.encode(Kind.done, forKey: .type)
            try container.encode(requestId, forKey: .requestId)
        case let .error(requestId, message):
            try container.encode(Kind.error, forKey: .type)
            try container.encodeIfPresent(requestId, forKey: .requestId)
            try container.encode(message, forKey: .message)
        }
    }
}

public enum SidecarIPCError: Error, Equatable {
    case invalidLine
    case notConnected
    case sidecarCrashed
    case timeout
    case pathTooLong
}
