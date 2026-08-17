import XCTest
@testable import SessionStore

final class SessionStoreTests: XCTestCase {
    func testLaunchQueryReturnsMetadataOnlyForFiftyMostRecent() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let dbURL = dir.appendingPathComponent("sessions.sqlite")
        let store = try SessionStore(databaseURL: dbURL)

        for i in 0..<55 {
            try store.insertSession(
                SessionMetadata(title: "Session \(i)", updatedAt: Date(timeIntervalSince1970: Double(i)), origin: .chat)
            )
            _ = try store.insertMessage(sessionId: store.lastInsertedSessionId!, role: "user", body: String(repeating: "x", count: 40_000))
        }

        let metadata = try store.fetchRecentSessionMetadata(limit: 50)
        XCTAssertEqual(metadata.count, 50)
        XCTAssertEqual(metadata.first?.title, "Session 54")
        XCTAssertFalse(try store.launchQueryTouchesMessageBodies())
    }
}
