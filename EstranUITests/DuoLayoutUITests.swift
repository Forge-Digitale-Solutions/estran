import XCTest

/// W-DUO — the wide window, on the one simulator that can be booted.
///
/// The Duo simulator is gone: its runtime sent PosterBoard into a crash loop and
/// froze the machine, so its display states cannot be driven here. The same
/// window shape is reachable on an iPhone 18 Pro Max in landscape (~956 × 440 pt,
/// regular width) and that is what this tour drives: it rotates the app, then
/// asserts **by geometry** that the layout really became two columns — the next
/// window card sits to the right of the answer card instead of below it — and
/// that the four tab labels and the answer survive the rotation.
///
/// Portrait is the folded-Duo shape: one column, ~440 pt wide.
@MainActor
final class DuoLayoutUITests: XCTestCase {
    private let tabTitles = ["Maintenant", "Spots", "Alertes", "Réglages"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTabsAndAnswerSurviveBothOrientations() {
        XCUIDevice.shared.orientation = .portrait
        // Leaves the device in the shape the next test expects, even on a
        // passing run.
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launch()
        dismissActivityPickerIfPresent(in: app)

        XCTAssertTrue(
            app.staticTexts["app.title"].waitForExistence(timeout: 15),
            "Home must load before the layout check")

        let answer = answerCard(in: app)
        XCTAssertTrue(answer.waitForExistence(timeout: 10), "the answer card is missing")
        assertTabLabels(in: app)
        attachScreenshot(named: "duo-portrait-home", in: app)

        // Portrait (folded Duo shape): one column. The next window card is
        // below the answer, on the same leading edge.
        let windowCard = nextWindowCard(in: app)
        XCTAssertTrue(windowCard.waitForExistence(timeout: 10))
        let portraitWindow = app.windows.firstMatch.frame
        XCTAssertGreaterThan(
            portraitWindow.height, portraitWindow.width, "portrait is the tall window")
        XCTAssertLessThan(
            windowCard.frame.minX,
            portraitWindow.midX,
            "single column: the next window card starts on the leading edge")
        XCTAssertGreaterThan(
            windowCard.frame.minY,
            answer.frame.minY,
            "single column: the next window card sits below the answer")

        rotate(to: .landscapeLeft, in: app)
        XCTAssertTrue(
            app.staticTexts["app.title"].waitForExistence(timeout: 10),
            "Home must still be on screen after rotation")

        assertTabLabels(in: app)
        XCTAssertTrue(answer.waitForExistence(timeout: 10), "the answer card left the screen")
        XCTAssertTrue(windowCard.waitForExistence(timeout: 10))

        let landscapeWindow = app.windows.firstMatch.frame
        XCTAssertGreaterThan(
            landscapeWindow.width, landscapeWindow.height, "landscape is the wide window")
        XCTAssertGreaterThan(
            landscapeWindow.width, 900,
            "the Pro Max landscape window is the same order of width as the unfolded Duo")
        XCTAssertGreaterThanOrEqual(
            windowCard.frame.minX,
            answer.frame.maxX - 1,
            "two columns: the next window card sits beside the answer card")
        attachScreenshot(named: "duo-landscape-home", in: app)

        // The wide spot detail is reachable from the same wide window; the map
        // card moved into its side column.
        openSpotDetail(in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label BEGINSWITH %@", "Marée"))
                .firstMatch.waitForExistence(timeout: 10),
            "the tide chart card must render in the wide window")
        attachScreenshot(named: "duo-landscape-spot-detail", in: app)
    }

    // MARK: - Assertions

    /// The four labels are the contract (`DESIGN_REFERENCE.md` §3.1). A tab bar,
    /// a sidebar or the minimised bar all expose them as buttons; the check
    /// accepts all three instead of pinning the tab bar's internal hierarchy.
    private func assertTabLabels(in app: XCUIApplication) {
        for title in tabTitles {
            let tab = app.buttons[title].firstMatch
            XCTAssertTrue(
                tab.waitForExistence(timeout: 5),
                "the « \(title) » tab label must stay reachable in every window shape")
        }
    }

    /// The answer card is one accessibility element whose label starts with the
    /// verdict (« Oui, pêche à pied. … » / « Non, balade. … »).
    private func answerCard(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(
                format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "Oui, ", "Non, "))
            .firstMatch
    }

    private func nextWindowCard(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Prochain bon créneau"))
            .firstMatch
    }

    // MARK: - Navigation

    private func dismissActivityPickerIfPresent(in app: XCUIApplication) {
        let title = app.staticTexts["Tu fais quoi ?"]
        guard title.waitForExistence(timeout: 8) else { return }
        app.buttons["Terminer"].firstMatch.tap()
        waitForLayout()
    }

    private func rotate(to orientation: UIDeviceOrientation, in app: XCUIApplication) {
        XCUIDevice.shared.orientation = orientation
        // The rotation animation plus the layout pass it triggers. There is no
        // public "rotation finished" signal; two seconds is the settled state
        // observed on this simulator.
        Thread.sleep(forTimeInterval: 2)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    private func openSpotDetail(in app: XCUIApplication) {
        app.buttons["Spots"].firstMatch.tap()
        waitForLayout()
        let detail = app.buttons["Voir le détail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 8), "spot detail entry missing")
        detail.tap()
        waitForLayout()
    }

    private func waitForLayout() {
        Thread.sleep(forTimeInterval: 0.9)
    }

    private func attachScreenshot(named name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
