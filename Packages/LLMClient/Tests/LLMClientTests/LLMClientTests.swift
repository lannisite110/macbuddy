import XCTest
@testable import LLMClient

final class LLMClientTests: XCTestCase {
    func testParsesSSETokenLine() {
        let line = #"data: {"choices":[{"delta":{"content":"Hi"}}]}"#
        XCTAssertEqual(LLMClient.token(fromSSELine: line), "Hi")
    }

    func testIgnoresDoneLine() {
        XCTAssertNil(LLMClient.token(fromSSELine: "data: [DONE]"))
    }
}
