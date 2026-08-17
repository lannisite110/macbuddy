import Foundation

public actor SidecarConnection {
    private let fd: Int32
    private let codec = LineCodec()
    private var pending = Data()

    public init(fd: Int32) {
        self.fd = fd
    }

    deinit {
        close(fd)
    }

    public func waitForReady(timeout: TimeInterval = 5) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let event = try readNextEvent(waitSeconds: 0.2) {
                if case .ready = event { return }
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw SidecarIPCError.timeout
    }

    public func send(_ request: SidecarRequest) throws {
        try UnixSocket.writeAll(fd, data: codec.encode(request))
    }

    public func readNextEvent(waitSeconds: TimeInterval = 30) throws -> SidecarEvent? {
        let deadline = Date().addingTimeInterval(waitSeconds)
        while Date() < deadline {
            if let event = try popEvent() {
                return event
            }
            var pollFD = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            _ = poll(&pollFD, 1, 100)
            var chunk = [UInt8](repeating: 0, count: 4096)
            let count = read(fd, &chunk, chunk.count)
            if count < 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK { continue }
                throw SidecarIPCError.notConnected
            }
            if count == 0 { return nil }
            pending.append(contentsOf: chunk.prefix(count))
        }
        return nil
    }

    public func streamEvents(forRequestId requestId: String) -> AsyncThrowingStream<SidecarEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    while true {
                        guard let event = try await self.readNextEvent(waitSeconds: 120) else {
                            continuation.finish(throwing: SidecarIPCError.notConnected)
                            return
                        }
                        switch event {
                        case .ready, .pong:
                            continue
                        case .token(let id, let text) where id == requestId:
                            continuation.yield(.token(requestId: id, text: text))
                        case .done(let id) where id == requestId:
                            continuation.yield(event)
                            continuation.finish()
                            return
                        case .error(let id?, let message) where id == requestId:
                            continuation.yield(event)
                            continuation.finish()
                            return
                        case .error(nil, let message):
                            continuation.finish(throwing: NSError(
                                domain: "SidecarIPC",
                                code: 1,
                                userInfo: [NSLocalizedDescriptionKey: message]
                            ))
                            return
                        default:
                            continue
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func popEvent() throws -> SidecarEvent? {
        guard let newlineIndex = pending.firstIndex(of: 0x0A) else { return nil }
        let line = pending.prefix(upTo: newlineIndex)
        pending.removeSubrange(...newlineIndex)
        guard !line.isEmpty else { return try popEvent() }
        return try codec.decode(SidecarEvent.self, from: line)
    }
}
