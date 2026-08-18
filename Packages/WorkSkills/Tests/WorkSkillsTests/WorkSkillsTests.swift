import XCTest
import LLMClient
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

    func testEmptyInputThrowsBeforeLLM() async {
        let engine = WorkEngine()
        do {
            _ = try await engine.run(
                action: .summarize,
                input: "   ",
                configuration: LLMConfiguration(baseURL: "http://127.0.0.1:11434/v1", model: "llama"),
                apiKey: nil
            )
            XCTFail("expected emptyInput")
        } catch let error as WorkSkillsError {
            XCTAssertEqual(error, .emptyInput)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }
}
