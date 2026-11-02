import XCTest

final class EstranUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesAndShowsTitle() {
        let app = XCUIApplication()
        app.launch()

        // A first launch opens the activity picker (frame 03) as a full-screen
        // cover, so Home is not in the accessibility tree until it closes.
        if app.staticTexts["Tu fais quoi ?"].waitForExistence(timeout: 8) {
            app.buttons["Terminer"].firstMatch.tap()
        }

        XCTAssertTrue(app.staticTexts["app.title"].waitForExistence(timeout: 10))
    }
}
