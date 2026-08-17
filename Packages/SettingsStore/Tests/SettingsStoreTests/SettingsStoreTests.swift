import XCTest
@testable import SettingsStore

final class SettingsStoreTests: XCTestCase {
    func testModelSettingsRoundTrip() {
        let store = SettingsStore()
        let settings = ModelSettings(baseURL: "https://api.example.com/v1", model: "gpt-4o-mini")
        store.saveModelSettings(settings)
        XCTAssertEqual(store.loadModelSettings(), settings)
    }
}
