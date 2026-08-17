import Foundation

public struct LLMConfiguration: Codable, Equatable, Sendable {
    public var baseURL: String
    public var model: String

    public init(baseURL: String, model: String) {
        self.baseURL = baseURL
        self.model = model
    }
}

public struct ChatMessage: Codable, Equatable, Sendable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public enum LLMClientError: Error, Equatable {
    case invalidURL
    case httpStatus(Int, String)
    case cancelled
    case emptyResponse
}

public actor LLMClient {
    private let baseURL: URL
    private let model: String
    private let apiKey: String?
    private let session: URLSession
    private var activeTask: Task<Void, Never>?

    public init(configuration: LLMConfiguration, apiKey: String? = nil, session: URLSession = .shared) throws {
        guard let url = URL(string: configuration.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw LLMClientError.invalidURL
        }
        self.baseURL = url
        self.model = configuration.model
        self.apiKey = apiKey
        self.session = session
    }

    public func cancel() {
        activeTask?.cancel()
        activeTask = nil
    }

    public func streamCompletion(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        let endpoint = baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        return AsyncThrowingStream { continuation in
            let task = Task {
                defer { Task { await self.clearActiveTask() } }
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    if Task.isCancelled {
                        continuation.finish(throwing: LLMClientError.cancelled)
                        return
                    }
                    guard let http = response as? HTTPURLResponse else {
                        continuation.finish(throwing: LLMClientError.emptyResponse)
                        return
                    }
                    guard (200 ... 299).contains(http.statusCode) else {
                        var errorData = Data()
                        for try await byte in bytes { errorData.append(byte) }
                        let text = String(data: errorData, encoding: .utf8) ?? ""
                        continuation.finish(throwing: LLMClientError.httpStatus(http.statusCode, text))
                        return
                    }

                    var buffer = ""
                    var emitted = false
                    for try await byte in bytes {
                        if Task.isCancelled {
                            continuation.finish(throwing: LLMClientError.cancelled)
                            return
                        }
                        buffer.append(Character(UnicodeScalar(byte)))
                        while let newlineRange = buffer.range(of: "\n") {
                            let line = String(buffer[..<newlineRange.lowerBound])
                            buffer.removeSubrange(...newlineRange.upperBound)
                            if let token = Self.token(fromSSELine: line) {
                                emitted = true
                                continuation.yield(token)
                            }
                        }
                    }
                    if emitted {
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: LLMClientError.emptyResponse)
                    }
                } catch is CancellationError {
                    continuation.finish(throwing: LLMClientError.cancelled)
                } catch let error as URLError where error.code == .cancelled {
                    continuation.finish(throwing: LLMClientError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            Task { await self.setActiveTask(task) }
        }
    }

    private func setActiveTask(_ task: Task<Void, Never>) {
        activeTask = task
    }

    private func clearActiveTask() {
        activeTask = nil
    }

    nonisolated static func token(fromSSELine line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("data: ") else { return nil }
        let payload = String(trimmed.dropFirst(6))
        if payload == "[DONE]" { return nil }
        guard
            let jsonData = payload.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let delta = choices.first?["delta"] as? [String: Any],
            let token = delta["content"] as? String,
            !token.isEmpty
        else { return nil }
        return token
    }
}
