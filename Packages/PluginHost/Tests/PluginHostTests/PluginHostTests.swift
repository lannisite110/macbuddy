import XCTest
@testable import PluginHost
import CryptoKit

final class PluginHostTests: XCTestCase {
    func testLoadValidPlugin() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let entry = "#!/bin/bash\necho hello"
        let entryURL = dir.appendingPathComponent("run.sh")
        try entry.write(to: entryURL, atomically: true, encoding: .utf8)
        let hash = SHA256.hash(data: Data(entry.utf8)).compactMap { String(format: "%02x", $0) }.joined()

        let manifest = """
        {"id":"demo","name":"Demo","version":"1.0","entry":"run.sh","sha256":"\(hash)","capabilities":["fs"]}
        """
        try manifest.write(to: dir.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)

        let plugin = try PluginHost().loadPlugin(at: dir)
        XCTAssertEqual(plugin.manifest.id, "demo")
    }

    func testRejectsBadHash() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try "echo".write(to: dir.appendingPathComponent("run.sh"), atomically: true, encoding: .utf8)
        let manifest = """
        {"id":"demo","name":"Demo","version":"1.0","entry":"run.sh","sha256":"bad","capabilities":[]}
        """
        try manifest.write(to: dir.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try PluginHost().loadPlugin(at: dir))
    }
}
