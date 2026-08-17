import XCTest
@testable import WorkflowTemplates

final class WorkflowTemplatesTests: XCTestCase {
    func testBuiltInTemplatesNotEmpty() {
        XCTAssertFalse(WorkflowCatalog.builtIn.isEmpty)
    }

    func testLookupById() {
        XCTAssertNotNil(WorkflowCatalog.template(id: "quick-summarize"))
    }
}
