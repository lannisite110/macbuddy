import XCTest
@testable import Telemetry

final class TelemetryTests: XCTestCase {
    func testAppendAndReadColdStarts() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let telemetry = Telemetry(directory: dir)
        try telemetry.record(PerfEvent(kind: .coldStart, durationMs: 900, timestamp: Date()))
        try telemetry.record(PerfEvent(kind: .hotkeyToVisible, durationMs: 40, timestamp: Date()))

        let cold = try telemetry.recentColdStarts(limit: 20)
        XCTAssertEqual(cold.count, 1)
        XCTAssertEqual(cold[0].durationMs, 900)
    }
}
