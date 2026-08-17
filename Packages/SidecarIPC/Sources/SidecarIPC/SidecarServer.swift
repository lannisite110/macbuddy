import Foundation
import LLMClient

public final class SidecarServer: @unchecked Sendable {
    private let socketPath: String
    private var listenFD: Int32?
    private let lock = NSLock()
    private var runningTasks: [String: Task<Void, Never>] = [:]

    public init(socketPath: String) {
        self.socketPath = socketPath
    }

    public func run() throws {
        let fd = try UnixSocket.bind(path: socketPath)
        listenFD = fd
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
                    let started = CFAbsoluteTimeGetCurrent()
                    let ms = (CFAbsoluteTimeGetCurrent() - started) * 1000
                    if let data = try? codec.encode(SidecarEvent.pong(latencyMs: ms)) {
                        try? UnixSocket.writeAll(fd, data: data)
                    }
                case let .cancel(requestId):
                    lock.lock()
                    runningTasks[requestId]?.cancel()
                    runningTasks[requestId] = nil
                    lock.unlock()
                case let .complete(requestId, configuration, apiKey, messages):
                    lock.lock()
                    runningTasks[requestId]?.cancel()
                    lock.unlock()
                    let task = Task {
                        do {
                            let client = try LLMClient(configuration: configuration, apiKey: apiKey)
                            let stream = await client.streamCompletion(messages: messages)
                            for try await token in stream {
                                if Task.isCancelled { return }
                                let event = SidecarEvent.token(requestId: requestId, text: token)
                                if let data = try? codec.encode(event) {
                                    try? UnixSocket.writeAll(fd, data: data)
                                }
                            }
                            if !Task.isCancelled {
                                if let data = try? codec.encode(SidecarEvent.done(requestId: requestId)) {
                                    try? UnixSocket.writeAll(fd, data: data)
                                }
                            }
                        } catch LLMClientError.cancelled {
                            return
                        } catch {
                            let message: String
                            if case LLMClientError.httpStatus(let code, let body) = error {
                                message = "HTTP \(code): \(body.prefix(200))"
                            } else {
                                message = String(describing: error)
                            }
                            if let data = try? codec.encode(SidecarEvent.error(requestId: requestId, message: message)) {
                                try? UnixSocket.writeAll(fd, data: data)
                            }
                        }
                        self.clearTask(requestId)
                    }
                    lock.lock()
                    runningTasks[requestId] = task
                    lock.unlock()
                }
            }
        }
    }

    private func clearTask(_ requestId: String) {
        lock.lock()
        runningTasks[requestId] = nil
        lock.unlock()
    }
}
