import Foundation

public final class LineCodec: Sendable {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {}

    public func encode<T: Encodable>(_ value: T) throws -> Data {
        var data = try encoder.encode(value)
        data.append(0x0A)
        return data
    }

    public func decode<T: Decodable>(_ type: T.Type, from line: Data) throws -> T {
        try decoder.decode(type, from: line)
    }
}

public final class LineBuffer: @unchecked Sendable {
    private var buffer = Data()
    private let lock = NSLock()

    public init() {}

    public func append(_ chunk: Data) -> [Data] {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(chunk)
        var lines: [Data] = []
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let line = buffer.prefix(upTo: newlineIndex)
            buffer.removeSubrange(...newlineIndex)
            if !line.isEmpty {
                lines.append(line)
            }
        }
        return lines
    }

    public func reset() {
        lock.lock()
        buffer.removeAll(keepingCapacity: true)
        lock.unlock()
    }
}

public enum UnixSocket {
    public static func bind(path: String) throws -> Int32 {
        unlink(path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8CString)
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            close(fd)
            throw SidecarIPCError.pathTooLong
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dest in
                for (index, byte) in pathBytes.enumerated() {
                    dest[index] = byte
                }
            }
        }
        let length = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, length)
            }
        }
        guard bindResult == 0 else {
            close(fd)
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        listen(fd, 4)
        return fd
    }

    public static func connect(path: String) throws -> Int32 {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8CString)
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dest in
                for (index, byte) in pathBytes.enumerated() {
                    dest[index] = byte
                }
            }
        }
        let length = socklen_t(MemoryLayout<sockaddr_un>.size)
        let connectResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, length)
            }
        }
        guard connectResult == 0 else {
            close(fd)
            throw SidecarIPCError.notConnected
        }
        return fd
    }

    public static func readAvailable(_ fd: Int32, max: Int = 4096) -> Data? {
        var chunk = [UInt8](repeating: 0, count: max)
        let count = recv(fd, &chunk, max, 0)
        if count == 0 { return nil }
        if count < 0 {
            if errno == EAGAIN || errno == EWOULDBLOCK { return Data() }
            return nil
        }
        return Data(chunk.prefix(count))
    }

    public static func writeAll(_ fd: Int32, data: Data) throws {
        try data.withUnsafeBytes { raw in
            var sent = 0
            while sent < raw.count {
                let wrote = write(fd, raw.baseAddress!.advanced(by: sent), raw.count - sent)
                guard wrote > 0 else {
                    throw SidecarIPCError.notConnected
                }
                sent += wrote
            }
        }
    }
}

private func unlink(_ path: String) {
    _ = path.withCString { Darwin.unlink($0) }
}
