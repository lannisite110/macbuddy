import XCTest
@testable import CodeEngine

final class IncrementalIndexTests: XCTestCase {
    func testMergeCountsUpdates() {
        let scanned = [
            WorkspaceEntry(relativePath: "a.swift", modificationDate: Date(timeIntervalSince1970: 1)),
            WorkspaceEntry(relativePath: "b.swift", modificationDate: Date(timeIntervalSince1970: 2)),
        ]
        var index = IncrementalIndex(workspacePath: "/tmp", records: [
            IndexRecord(relativePath: "a.swift", modificationTime: 1),
        ])
        let stats = index.merge(with: scanned)
        XCTAssertEqual(stats.unchanged, 1)
        XCTAssertEqual(stats.updated, 1)
    }
}
