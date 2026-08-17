import XCTest
@testable import WorkSkills

final class WorkSkillsTests: XCTestCase {
    func testSummarizePromptIncludesInput() {
        let prompt = WorkPrompts.userPrompt(for: .summarize, text: "hello world")
        XCTAssertTrue(prompt.contains("hello world"))
        XCTAssertTrue(prompt.lowercased().contains("summarize"))
    }

    func testFileReaderRejectsMissingFile() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertThrowsError(try FileTextReader.readText(from: url)) { error in
            XCTAssertEqual(error as? WorkSkillsError, .notAFile)
        }
    }

    func testFileReaderReadsSmallFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).txt")
        try "sample content".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(try FileTextReader.readText(from: url), "sample content")
    }
}
