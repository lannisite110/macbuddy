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

    func testCommandRunnerRejectsGitConfigInjection() {
        let tmp = FileManager.default.temporaryDirectory
        XCTAssertThrowsError(
            try CommandRunner.run(
                executable: "git",
                arguments: ["-c", "alias.x=!whoami", "diff"],
                workspace: tmp
            )
        ) { error in
            guard case CodeEngineError.commandNotAllowed = error else {
                return XCTFail("expected commandNotAllowed")
            }
        }
    }

    func testCommandRunnerAllowsGitDiff() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let initProcess = Process()
        initProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        initProcess.arguments = ["init", "-q"]
        initProcess.currentDirectoryURL = tmp
        try initProcess.run()
        initProcess.waitUntilExit()
        _ = try CommandRunner.run(executable: "git", arguments: ["diff"], workspace: tmp)
    }

    func testWorkspacePathRejectsParentTraversal() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertThrowsError(try WorkspacePath.resolve(relativePath: "../outside.txt", workspace: root)) { error in
            guard case CodeEngineError.pathOutsideWorkspace = error else {
                return XCTFail("expected pathOutsideWorkspace")
            }
        }
    }

    func testWorkspacePathRejectsAbsolutePath() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertThrowsError(try WorkspacePath.resolve(relativePath: "/etc/passwd", workspace: root)) { error in
            guard case CodeEngineError.pathOutsideWorkspace = error else {
                return XCTFail("expected pathOutsideWorkspace")
            }
        }
    }

    func testFileReaderRejectsTraversal() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertThrowsError(try FileReader.read(relativePath: "../outside.txt", workspace: root)) { error in
            guard case CodeEngineError.pathOutsideWorkspace = error else {
                return XCTFail("expected pathOutsideWorkspace")
            }
        }
    }

    func testPatchApplierRejectsTraversal() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let change = PatchFileChange(relativePath: "../../escape.txt", oldContent: "", newContent: "pwn", unifiedDiff: "")
        XCTAssertThrowsError(try PatchApplier.apply(change: change, workspace: root))
    }

    func testWorkspacePathAllowsNestedFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = root.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let file = nested.appendingPathComponent("main.swift")
        try "print(1)".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: root) }

        let content = try FileReader.read(relativePath: "src/main.swift", workspace: root)
        XCTAssertEqual(content, "print(1)")
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
