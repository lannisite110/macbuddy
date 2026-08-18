import CodeEngine
import Foundation
import LLMClient
import SidecarIPC

public final class CodeSidecarServer: @unchecked Sendable {
    private let socketPath: String
    private let lock = NSLock()
    private var runningTasks: [String: Task<Void, Never>] = [:]
    private let engine = CodeEngine()

    public init(socketPath: String) {
        self.socketPath = socketPath
    }

    public func run() throws {
        let fd = try UnixSocket.bind(path: socketPath)
        defer {
            close(fd)
            _ = socketPath.withCString { Darwin.unlink($0) }
        }

        while true {
            let clientFD = accept(fd, nil, nil)
            guard clientFD >= 0 else { continue }
            DispatchQueue.global(qos: .userInitiated).async {
                self.handleClient(clientFD)
            }
        }
    }

    private func handleClient(_ fd: Int32) {
        defer { close(fd) }
        let codec = LineCodec()
        let buffer = LineBuffer()
        var readBuffer = [UInt8](repeating: 0, count: 4096)

        do {
            try UnixSocket.writeAll(fd, data: try codec.encode(SidecarEvent.ready))
        } catch {
            return
        }

        while true {
            let count = read(fd, &readBuffer, readBuffer.count)
            if count <= 0 { break }
            let lines = buffer.append(Data(readBuffer.prefix(count)))
            for line in lines {
                guard let request = try? codec.decode(SidecarRequest.self, from: line) else { continue }
                switch request {
                case .ping:
                    if let data = try? codec.encode(SidecarEvent.pong(latencyMs: 0)) {
                        try? UnixSocket.writeAll(fd, data: data)
                    }
                case let .cancel(requestId):
                    lock.lock()
                    runningTasks[requestId]?.cancel()
                    runningTasks[requestId] = nil
                    lock.unlock()
                case let .codeOpen(requestId, workspacePath, storageDirectory, incrementalIndexEnabled):
                    start(requestId) {
                        await self.open(
                            fd: fd,
                            codec: codec,
                            requestId: requestId,
                            workspacePath: workspacePath,
                            storageDirectory: storageDirectory,
                            incrementalIndexEnabled: incrementalIndexEnabled
                        )
                    }
                case let .codeClose(requestId):
                    start(requestId) {
                        await self.engine.closeWorkspace()
                        self.emit(fd, codec, .done(requestId: requestId))
                    }
                case let .codePatch(requestId, prompt, configuration, apiKey):
                    start(requestId) {
                        await self.patch(
                            fd: fd,
                            codec: codec,
                            requestId: requestId,
                            prompt: prompt,
                            configuration: configuration,
                            apiKey: apiKey
                        )
                    }
                case let .codeApply(requestId, previewJSON):
                    start(requestId) {
                        await self.apply(fd: fd, codec: codec, requestId: requestId, previewJSON: previewJSON)
                    }
                case let .codeGit(requestId, action):
                    start(requestId) {
                        await self.git(fd: fd, codec: codec, requestId: requestId, action: action)
                    }
                default:
                    if let requestId = request.requestId {
                        emit(fd, codec, .error(requestId: requestId, message: "unsupported on Code sidecar"))
                    }
                }
            }
        }
    }

    private func start(_ requestId: String, _ body: @escaping @Sendable () async -> Void) {
        lock.lock()
        runningTasks[requestId]?.cancel()
        lock.unlock()
        let task = Task {
            await body()
            self.clearTask(requestId)
        }
        lock.lock()
        runningTasks[requestId] = task
        lock.unlock()
    }

    private func open(
        fd: Int32,
        codec: LineCodec,
        requestId: String,
        workspacePath: String,
        storageDirectory: String,
        incrementalIndexEnabled: Bool
    ) async {
        do {
            let url = URL(fileURLWithPath: workspacePath)
            try await engine.openWorkspace(
                url,
                storageDirectory: URL(fileURLWithPath: storageDirectory),
                incrementalIndexEnabled: incrementalIndexEnabled
            )
            let stats = await engine.lastIndexStats ?? IncrementalIndexStats(enabled: false, unchanged: 0, updated: 0)
            let result = CodeOpenResult(workspaceName: url.lastPathComponent, stats: stats)
            emitJSON(fd, codec, requestId: requestId, value: result)
        } catch {
            emit(fd, codec, .error(requestId: requestId, message: String(describing: error)))
        }
    }

    private func patch(
        fd: Int32,
        codec: LineCodec,
        requestId: String,
        prompt: String,
        configuration: LLMConfiguration,
        apiKey: String?
    ) async {
        do {
            let preview = try await engine.proposePatch(prompt: prompt, configuration: configuration, apiKey: apiKey)
            if Task.isCancelled { return }
            emitJSON(fd, codec, requestId: requestId, value: preview)
        } catch {
            emit(fd, codec, .error(requestId: requestId, message: describe(error)))
        }
    }

    private func apply(fd: Int32, codec: LineCodec, requestId: String, previewJSON: String) async {
        do {
            guard let data = previewJSON.data(using: .utf8) else {
                emit(fd, codec, .error(requestId: requestId, message: "invalid preview"))
                return
            }
            let preview = try JSONDecoder().decode(PatchPreview.self, from: data)
            try await engine.apply(preview: preview)
            emit(fd, codec, .done(requestId: requestId))
        } catch {
            emit(fd, codec, .error(requestId: requestId, message: describe(error)))
        }
    }

    private func git(fd: Int32, codec: LineCodec, requestId: String, action: String) async {
        do {
            let output: String
            switch action {
            case "diff":
                output = try await engine.explainGitDiff()
            case "log":
                output = try await engine.explainGitLog()
            default:
                emit(fd, codec, .error(requestId: requestId, message: "unknown git action"))
                return
            }
            emit(fd, codec, .token(requestId: requestId, text: output))
            emit(fd, codec, .done(requestId: requestId))
        } catch {
            emit(fd, codec, .error(requestId: requestId, message: describe(error)))
        }
    }

    private func emitJSON<T: Encodable>(_ fd: Int32, _ codec: LineCodec, requestId: String, value: T) {
        do {
            let data = try JSONEncoder().encode(value)
            let text = String(data: data, encoding: .utf8) ?? "{}"
            emit(fd, codec, .token(requestId: requestId, text: text))
            emit(fd, codec, .done(requestId: requestId))
        } catch {
            emit(fd, codec, .error(requestId: requestId, message: String(describing: error)))
        }
    }

    private func emit(_ fd: Int32, _ codec: LineCodec, _ event: SidecarEvent) {
        if let data = try? codec.encode(event) {
            try? UnixSocket.writeAll(fd, data: data)
        }
    }

    private func describe(_ error: Error) -> String {
        if case LLMClientError.httpStatus(let code, let body) = error {
            return "HTTP \(code): \(body.prefix(200))"
        }
        return String(describing: error)
    }

    private func clearTask(_ requestId: String) {
        lock.lock()
        runningTasks[requestId] = nil
        lock.unlock()
    }
}
