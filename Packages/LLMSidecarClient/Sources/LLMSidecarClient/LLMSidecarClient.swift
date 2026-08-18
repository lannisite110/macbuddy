import Foundation
import LLMClient
import SidecarIPC

public actor LLMSidecarClient {
    private let process = SidecarProcess(helperName: "MacBuddyLLM", socketURL: SidecarPaths.llmSocketURL())
    private var connection: SidecarConnection?
    private var activeRequestId: String?

    public init() {}

    public func cancel() async {
        if let activeRequestId {
            try? await connection?.send(.cancel(requestId: activeRequestId))
        }
        self.activeRequestId = nil
    }

    public func ping() async throws -> Double {
        let conn = try await ensureConnection()
        try await conn.send(.ping)
        while let event = try await conn.readNextEvent(waitSeconds: 5) {
            if case let .pong(latencyMs) = event {
                return latencyMs
            }
        }
        throw SidecarIPCError.timeout
    }

    public func streamCompletion(
        messages: [ChatMessage],
        configuration: LLMConfiguration,
        apiKey: String?
    ) -> AsyncThrowingStream<String, Error> {
        let requestId = UUID().uuidString
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    self.activeRequestId = requestId
                    defer { Task { await self.clearActiveRequest() } }
                    try await self.streamOnce(
                        requestId: requestId,
                        messages: messages,
                        configuration: configuration,
                        apiKey: apiKey,
                        continuation: continuation,
                        allowRetry: true
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func streamOnce(
        requestId: String,
        messages: [ChatMessage],
        configuration: LLMConfiguration,
        apiKey: String?,
        continuation: AsyncThrowingStream<String, Error>.Continuation,
        allowRetry: Bool
    ) async throws {
        var yielded = false
        do {
            let conn = try await ensureConnection()
            try await conn.send(.complete(
                requestId: requestId,
                configuration: configuration,
                apiKey: apiKey,
                messages: messages
            ))
            while true {
                guard let event = try await conn.readNextEvent(waitSeconds: 120) else {
                    throw SidecarIPCError.notConnected
                }
                switch event {
                case .ready, .pong:
                    continue
                case let .token(id, text) where id == requestId:
                    yielded = true
                    continuation.yield(text)
                case .done(let id) where id == requestId:
                    continuation.finish()
                    return
                case let .error(id?, message) where id == requestId:
                    continuation.finish(throwing: LLMClientError.httpStatus(502, message))
                    return
                case .error(nil, let message):
                    continuation.finish(throwing: LLMClientError.httpStatus(502, message))
                    return
                default:
                    continue
                }
            }
        } catch {
            if allowRetry, !yielded, SidecarRecovery.isRecoverable(error) {
                await reset()
                try await streamOnce(
                    requestId: requestId,
                    messages: messages,
                    configuration: configuration,
                    apiKey: apiKey,
                    continuation: continuation,
                    allowRetry: false
                )
                return
            }
            throw error
        }
    }

    private func ensureConnection() async throws -> SidecarConnection {
        if let connection, await process.isRunning {
            return connection
        }
        connection = nil
        let path = try await process.ensureRunning()
        let deadline = Date().addingTimeInterval(5)
        var lastError: Error = SidecarLaunchError.notReady
        while Date() < deadline {
            do {
                let fd = try UnixSocket.connect(path: path)
                let conn = SidecarConnection(fd: fd)
                try await conn.waitForReady()
                connection = conn
                return conn
            } catch {
                lastError = error
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        throw lastError
    }

    public func reset() async {
        connection = nil
        activeRequestId = nil
        await process.terminate()
    }

    private func clearActiveRequest() {
        activeRequestId = nil
    }
}
