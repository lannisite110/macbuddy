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
}
