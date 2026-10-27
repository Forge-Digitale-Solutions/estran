import XCTest

final class EstranUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesAndShowsTitle() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["app.title"].waitForExistence(timeout: 10))
    }
}
