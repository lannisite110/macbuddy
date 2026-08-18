import XCTest
@testable import CodeEngine

final class CodeEngineTests: XCTestCase {
    func testMentionParser() {
        let mentions = MentionParser.extractMentions(from: "fix @src/main.swift and @README.md")
        XCTAssertEqual(mentions, ["src/main.swift", "README.md"])
    }

    func testUnifiedDiffMarksChanges() {
        let diff = UnifiedDiff.make(path: "a.txt", old: "one\ntwo", new: "one\ntwo\nthree")
        XCTAssertTrue(diff.contains("+three"))
    }

    func testPatchParser() {
        let response = """
        FILE: foo.swift
        ```
        let x = 1
        ```
        """
        let parsed = PatchParser.parse(response)
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].path, "foo.swift")
        XCTAssertTrue(parsed[0].content.contains("let x = 1"))
    }

    func testCommandRunnerRejectsCurl() {
        let tmp = FileManager.default.temporaryDirectory
        XCTAssertThrowsError(try CommandRunner.run(executable: "git", arguments: ["curl"], workspace: tmp)) { error in
            if case CodeEngineError.commandNotAllowed = error {} else {
                XCTFail("expected commandNotAllowed")
            }
        }
    }

    func testIgnoreRulesSkipsNodeModules() {
        XCTAssertTrue(IgnoreRules.shouldIgnore(relativePath: "foo/node_modules/bar", workspacePatterns: []))
    }

    func testPatchPreviewJSONRoundTrip() throws {
        let preview = PatchPreview(
            summary: "edit",
            changes: [
                PatchFileChange(relativePath: "a.swift", oldContent: "old", newContent: "new", unifiedDiff: "-old\n+new"),
            ]
        )
        let data = try JSONEncoder().encode(preview)
        let decoded = try JSONDecoder().decode(PatchPreview.self, from: data)
        XCTAssertEqual(decoded.summary, "edit")
        XCTAssertEqual(decoded.changes.first?.relativePath, "a.swift")
        XCTAssertEqual(decoded.changes.first?.newContent, "new")
    }
}
