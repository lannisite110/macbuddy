import Foundation
import LLMClient

public enum SidecarRequest: Codable, Sendable {
    case ping
    case complete(requestId: String, configuration: LLMConfiguration, apiKey: String?, messages: [ChatMessage])
    case cancel(requestId: String)
    case work(requestId: String, action: String, input: String, configuration: LLMConfiguration, apiKey: String?)
    case codeOpen(requestId: String, workspacePath: String, storageDirectory: String, incrementalIndexEnabled: Bool)
    case codeClose(requestId: String)
    case codePatch(requestId: String, prompt: String, configuration: LLMConfiguration, apiKey: String?)
    case codeApply(requestId: String, previewJSON: String)
    case codeGit(requestId: String, action: String)

    private enum CodingKeys: String, CodingKey {
        case type, requestId, configuration, apiKey, messages, action, input
        case workspacePath, storageDirectory, incrementalIndexEnabled, prompt, previewJSON, gitAction
    }

    private enum Kind: String, Codable {
        case ping, complete, cancel, work
        case codeOpen, codeClose, codePatch, codeApply, codeGit
    }

    public var requestId: String? {
        switch self {
        case .ping:
            return nil
        case let .complete(requestId, _, _, _),
             let .cancel(requestId),
             let .work(requestId, _, _, _, _),
             let .codeOpen(requestId, _, _, _),
             let .codeClose(requestId),
             let .codePatch(requestId, _, _, _),
             let .codeApply(requestId, _),
             let .codeGit(requestId, _):
            return requestId
        }
    }

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
        case .work:
            self = try .work(
                requestId: container.decode(String.self, forKey: .requestId),
                action: container.decode(String.self, forKey: .action),
                input: container.decode(String.self, forKey: .input),
                configuration: container.decode(LLMConfiguration.self, forKey: .configuration),
                apiKey: container.decodeIfPresent(String.self, forKey: .apiKey)
            )
        case .codeOpen:
            self = try .codeOpen(
                requestId: container.decode(String.self, forKey: .requestId),
                workspacePath: container.decode(String.self, forKey: .workspacePath),
                storageDirectory: container.decode(String.self, forKey: .storageDirectory),
                incrementalIndexEnabled: container.decode(Bool.self, forKey: .incrementalIndexEnabled)
            )
        case .codeClose:
            self = try .codeClose(requestId: container.decode(String.self, forKey: .requestId))
        case .codePatch:
            self = try .codePatch(
                requestId: container.decode(String.self, forKey: .requestId),
                prompt: container.decode(String.self, forKey: .prompt),
                configuration: container.decode(LLMConfiguration.self, forKey: .configuration),
                apiKey: container.decodeIfPresent(String.self, forKey: .apiKey)
            )
        case .codeApply:
            self = try .codeApply(
                requestId: container.decode(String.self, forKey: .requestId),
                previewJSON: container.decode(String.self, forKey: .previewJSON)
            )
        case .codeGit:
            self = try .codeGit(
                requestId: container.decode(String.self, forKey: .requestId),
                action: container.decode(String.self, forKey: .gitAction)
            )
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
        case let .work(requestId, action, input, configuration, apiKey):
            try container.encode(Kind.work, forKey: .type)
            try container.encode(requestId, forKey: .requestId)
            try container.encode(action, forKey: .action)
            try container.encode(input, forKey: .input)
            try container.encode(configuration, forKey: .configuration)
            try container.encodeIfPresent(apiKey, forKey: .apiKey)
        case let .codeOpen(requestId, workspacePath, storageDirectory, incrementalIndexEnabled):
            try container.encode(Kind.codeOpen, forKey: .type)
            try container.encode(requestId, forKey: .requestId)
            try container.encode(workspacePath, forKey: .workspacePath)
            try container.encode(storageDirectory, forKey: .storageDirectory)
            try container.encode(incrementalIndexEnabled, forKey: .incrementalIndexEnabled)
        case let .codeClose(requestId):
            try container.encode(Kind.codeClose, forKey: .type)
            try container.encode(requestId, forKey: .requestId)
        case let .codePatch(requestId, prompt, configuration, apiKey):
            try container.encode(Kind.codePatch, forKey: .type)
            try container.encode(requestId, forKey: .requestId)
            try container.encode(prompt, forKey: .prompt)
            try container.encode(configuration, forKey: .configuration)
            try container.encodeIfPresent(apiKey, forKey: .apiKey)
        case let .codeApply(requestId, previewJSON):
            try container.encode(Kind.codeApply, forKey: .type)
            try container.encode(requestId, forKey: .requestId)
            try container.encode(previewJSON, forKey: .previewJSON)
        case let .codeGit(requestId, action):
            try container.encode(Kind.codeGit, forKey: .type)
            try container.encode(requestId, forKey: .requestId)
            try container.encode(action, forKey: .gitAction)
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
