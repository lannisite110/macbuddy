import Foundation
import LLMClient
import SidecarIPC
import WorkSkills

public actor WorkSidecarClient {
    private let process = SidecarProcess(helperName: "MacBuddyWork", socketURL: SidecarPaths.workSocketURL())
    private var connection: SidecarConnection?
    private var activeRequestId: String?

    public init() {}

    public func cancel() async {
        if let activeRequestId {
            try? await connection?.send(.cancel(requestId: activeRequestId))
        }
        self.activeRequestId = nil
    }

    public func run(
        action: WorkAction,
        input: String,
        configuration: LLMConfiguration,
        apiKey: String?
    ) async throws -> String {
        let requestId = UUID().uuidString
        activeRequestId = requestId
        defer { activeRequestId = nil }

        let conn = try await connect()
        try await conn.send(.work(
            requestId: requestId,
            action: action.rawValue,
            input: input,
            configuration: configuration,
            apiKey: apiKey
        ))

        do {
            return try await collectText(conn: conn, requestId: requestId)
        } catch {
            guard SidecarRecovery.isRecoverable(error) else { throw error }
            await reset()
            let retry = try await connect()
            try await retry.send(.work(
                requestId: requestId,
                action: action.rawValue,
                input: input,
                configuration: configuration,
                apiKey: apiKey
            ))
            return try await collectText(conn: retry, requestId: requestId)
        }
    }

    public func reset() async {
        connection = nil
        activeRequestId = nil
        await process.terminate()
    }

    private func collectText(conn: SidecarConnection, requestId: String) async throws -> String {
        var output = ""
        while true {
            guard let event = try await conn.readNextEvent(waitSeconds: 120) else {
                throw SidecarIPCError.notConnected
            }
            switch event {
            case .ready, .pong:
                continue
            case let .token(id, text) where id == requestId:
                output += text
            case .done(let id) where id == requestId:
                let result = output.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !result.isEmpty else { throw LLMClientError.emptyResponse }
                return result
            case let .error(id?, message) where id == requestId:
                if message == "empty input" {
                    throw WorkSkillsError.emptyInput
                }
                throw LLMClientError.httpStatus(502, message)
            case .error(nil, let message):
                throw LLMClientError.httpStatus(502, message)
            default:
                continue
            }
        }
    }

    private func connect() async throws -> SidecarConnection {
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
}
