import CodeEngine
import Foundation
import LLMClient
import SidecarIPC

public actor CodeSidecarClient {
    private let process = SidecarProcess(helperName: "MacBuddyCode", socketURL: SidecarPaths.codeSocketURL())
    private var connection: SidecarConnection?

    public init() {}

    public func terminate() async {
        await process.terminate()
        connection = nil
    }

    public func reset() async {
        await terminate()
    }

    public func openWorkspace(
        _ url: URL,
        storageDirectory: URL,
        incrementalIndexEnabled: Bool
    ) async throws -> CodeOpenResult {
        let text = try await sendAndCollect(
            .codeOpen(
                requestId: UUID().uuidString,
                workspacePath: url.path,
                storageDirectory: storageDirectory.path,
                incrementalIndexEnabled: incrementalIndexEnabled
            )
        )
        guard let data = text.data(using: .utf8) else {
            throw SidecarIPCError.invalidLine
        }
        return try JSONDecoder().decode(CodeOpenResult.self, from: data)
    }

    public func closeWorkspace() async {
        _ = try? await sendAndCollect(.codeClose(requestId: UUID().uuidString), allowEmpty: true)
        await terminate()
    }

    public func proposePatch(
        prompt: String,
        configuration: LLMConfiguration,
        apiKey: String?
    ) async throws -> PatchPreview {
        let text = try await sendAndCollect(
            .codePatch(
                requestId: UUID().uuidString,
                prompt: prompt,
                configuration: configuration,
                apiKey: apiKey
            )
        )
        guard let data = text.data(using: .utf8) else {
            throw SidecarIPCError.invalidLine
        }
        return try JSONDecoder().decode(PatchPreview.self, from: data)
    }

    public func apply(preview: PatchPreview) async throws {
        let data = try JSONEncoder().encode(preview)
        let json = String(data: data, encoding: .utf8) ?? "{}"
        _ = try await sendAndCollect(
            .codeApply(requestId: UUID().uuidString, previewJSON: json),
            allowEmpty: true
        )
    }

    public func explainGitDiff() async throws -> String {
        try await sendAndCollect(.codeGit(requestId: UUID().uuidString, action: "diff"), allowEmpty: true)
    }

    public func explainGitLog() async throws -> String {
        try await sendAndCollect(.codeGit(requestId: UUID().uuidString, action: "log"), allowEmpty: true)
    }

    private func sendAndCollect(_ request: SidecarRequest, allowEmpty: Bool = false) async throws -> String {
        let requestId = request.requestId ?? UUID().uuidString
        do {
            return try await sendOnce(request, requestId: requestId, allowEmpty: allowEmpty)
        } catch {
            guard SidecarRecovery.isRecoverable(error) else { throw error }
            await reset()
            return try await sendOnce(request, requestId: requestId, allowEmpty: allowEmpty)
        }
    }

    private func sendOnce(_ request: SidecarRequest, requestId: String, allowEmpty: Bool) async throws -> String {
        let conn = try await ensureConnection()
        try await conn.send(request)
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
                if !allowEmpty, output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw LLMClientError.emptyResponse
                }
                return output
            case let .error(id?, message) where id == requestId:
                throw LLMClientError.httpStatus(502, message)
            case .error(nil, let message):
                throw LLMClientError.httpStatus(502, message)
            default:
                continue
            }
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
}
