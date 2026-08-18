import Foundation
import LLMClient
import SidecarIPC
import WorkSkills

public final class WorkSidecarServer: @unchecked Sendable {
    private let socketPath: String
    private let lock = NSLock()
    private var runningTasks: [String: Task<Void, Never>] = [:]

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
                    let ms = 0.0
                    if let data = try? codec.encode(SidecarEvent.pong(latencyMs: ms)) {
                        try? UnixSocket.writeAll(fd, data: data)
                    }
                case let .cancel(requestId):
                    lock.lock()
                    runningTasks[requestId]?.cancel()
                    runningTasks[requestId] = nil
                    lock.unlock()
                case let .complete(requestId, _, _, _):
                    if let data = try? codec.encode(SidecarEvent.error(requestId: requestId, message: "unsupported on Work sidecar")) {
                        try? UnixSocket.writeAll(fd, data: data)
                    }
                case let .work(requestId, actionRaw, input, configuration, apiKey):
                    lock.lock()
                    runningTasks[requestId]?.cancel()
                    lock.unlock()
                    let task = Task {
                        await self.runWork(
                            fd: fd,
                            codec: codec,
                            requestId: requestId,
                            actionRaw: actionRaw,
                            input: input,
                            configuration: configuration,
                            apiKey: apiKey
                        )
                    }
                    lock.lock()
                    runningTasks[requestId] = task
                    lock.unlock()
                default:
                    if let requestId = request.requestId {
                        emit(fd, codec, .error(requestId: requestId, message: "unsupported on Work sidecar"))
                    }
                }
            }
        }
    }

    private func runWork(
        fd: Int32,
        codec: LineCodec,
        requestId: String,
        actionRaw: String,
        input: String,
        configuration: LLMConfiguration,
        apiKey: String?
    ) async {
        defer { clearTask(requestId) }
        guard let action = WorkAction(rawValue: actionRaw) else {
            emit(fd, codec, .error(requestId: requestId, message: "unknown work action"))
            return
        }
        do {
            let engine = WorkEngine()
            let output = try await engine.run(
                action: action,
                input: input,
                configuration: configuration,
                apiKey: apiKey
            )
            if Task.isCancelled { return }
            emit(fd, codec, .token(requestId: requestId, text: output))
            emit(fd, codec, .done(requestId: requestId))
        } catch is CancellationError {
            return
        } catch LLMClientError.cancelled {
            return
        } catch WorkSkillsError.emptyInput {
            emit(fd, codec, .error(requestId: requestId, message: "empty input"))
        } catch {
            let message: String
            if case LLMClientError.httpStatus(let code, let body) = error {
                message = "HTTP \(code): \(body.prefix(200))"
            } else {
                message = String(describing: error)
            }
            emit(fd, codec, .error(requestId: requestId, message: message))
        }
    }

    private func emit(_ fd: Int32, _ codec: LineCodec, _ event: SidecarEvent) {
        if let data = try? codec.encode(event) {
            try? UnixSocket.writeAll(fd, data: data)
        }
    }

    private func clearTask(_ requestId: String) {
        lock.lock()
        runningTasks[requestId] = nil
        lock.unlock()
    }
}
