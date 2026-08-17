import SidecarIPC
import XCTest

final class SidecarIntegrationTests: XCTestCase {
    func testSidecarPing() async throws {
        let socket = URL(fileURLWithPath: "/tmp/mb-\(UUID().uuidString.prefix(8)).sock")
        let server = SidecarServer(socketPath: socket.path)

        let serverQueue = DispatchQueue(label: "sidecar-test-server")
        serverQueue.async {
            try? server.run()
        }
        defer {
            if FileManager.default.fileExists(atPath: socket.path) {
                try? FileManager.default.removeItem(at: socket)
            }
        }

        var fd: Int32 = -1
        let connectDeadline = Date().addingTimeInterval(5)
        while Date() < connectDeadline {
            if FileManager.default.fileExists(atPath: socket.path) {
                if let connected = try? UnixSocket.connect(path: socket.path) {
                    fd = connected
                    break
                }
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertGreaterThanOrEqual(fd, 0)

        let connection = SidecarConnection(fd: fd)
        try await connection.waitForReady()
        try await connection.send(.ping)

        var gotPong = false
        let pongDeadline = Date().addingTimeInterval(3)
        while Date() < pongDeadline {
            if let event = try await connection.readNextEvent(waitSeconds: 1) {
                if case .pong = event {
                    gotPong = true
                    break
                }
            }
        }
        XCTAssertTrue(gotPong)
    }
}
