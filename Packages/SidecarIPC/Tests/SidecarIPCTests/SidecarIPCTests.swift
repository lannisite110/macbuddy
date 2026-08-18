import LLMClient
import SidecarIPC
import XCTest

final class SidecarIPCTests: XCTestCase {
    func testRoundTripCompleteRequest() throws {
        let request = SidecarRequest.complete(
            requestId: "abc",
            configuration: LLMConfiguration(baseURL: "http://127.0.0.1:11434/v1", model: "llama"),
            apiKey: nil,
            messages: [ChatMessage(role: "user", content: "hi")]
        )
        let data = try LineCodec().encode(request)
        let decoded = try LineCodec().decode(SidecarRequest.self, from: data.dropLast())
        if case let .complete(id, config, _, messages) = decoded {
            XCTAssertEqual(id, "abc")
            XCTAssertEqual(config.model, "llama")
            XCTAssertEqual(messages.first?.content, "hi")
        } else {
            XCTFail("expected complete")
        }
    }

    func testTokenEventRoundTrip() throws {
        let event = SidecarEvent.token(requestId: "1", text: "hello")
        let data = try LineCodec().encode(event)
        let decoded = try LineCodec().decode(SidecarEvent.self, from: data.dropLast())
        XCTAssertEqual(decoded, event)
    }

    func testRoundTripWorkRequest() throws {
        let request = SidecarRequest.work(
            requestId: "w1",
            action: "summarize",
            input: "notes",
            configuration: LLMConfiguration(baseURL: "http://127.0.0.1:11434/v1", model: "llama"),
            apiKey: nil
        )
        let data = try LineCodec().encode(request)
        let decoded = try LineCodec().decode(SidecarRequest.self, from: data.dropLast())
        if case let .work(id, action, input, config, _) = decoded {
            XCTAssertEqual(id, "w1")
            XCTAssertEqual(action, "summarize")
            XCTAssertEqual(input, "notes")
            XCTAssertEqual(config.model, "llama")
        } else {
            XCTFail("expected work")
        }
    }

    func testRoundTripCodeOpenRequest() throws {
        let request = SidecarRequest.codeOpen(
            requestId: "c1",
            workspacePath: "/tmp/proj",
            storageDirectory: "/tmp/index",
            incrementalIndexEnabled: false
        )
        let data = try LineCodec().encode(request)
        let decoded = try LineCodec().decode(SidecarRequest.self, from: data.dropLast())
        if case let .codeOpen(id, workspace, storage, enabled) = decoded {
            XCTAssertEqual(id, "c1")
            XCTAssertEqual(workspace, "/tmp/proj")
            XCTAssertEqual(storage, "/tmp/index")
            XCTAssertFalse(enabled)
        } else {
            XCTFail("expected codeOpen")
        }
    }

    func testRecoverableDisconnect() {
        XCTAssertTrue(SidecarRecovery.isRecoverable(SidecarIPCError.notConnected))
        XCTAssertTrue(SidecarRecovery.isRecoverable(SidecarIPCError.sidecarCrashed))
        XCTAssertTrue(SidecarRecovery.isRecoverable(SidecarIPCError.timeout))
        XCTAssertFalse(SidecarRecovery.isRecoverable(SidecarLaunchError.helperMissing))
        XCTAssertFalse(SidecarRecovery.isRecoverable(SidecarIPCError.invalidLine))
        let message = SidecarRecovery.message(sidecarName: "LLM", error: SidecarIPCError.notConnected)
        XCTAssertTrue(message.contains("Retry"))
    }
}
