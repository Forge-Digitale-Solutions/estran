import XCTest

/// W-DUO — the wide window, on any simulator that can still be booted.
///
/// The Duo simulator is gone: its runtime sent PosterBoard into a crash loop and
/// froze the machine, so its display states cannot be driven here. The same
/// window shape is reachable by rotating any iPhone whose landscape window is at
/// least `OceanLayout.wideBreakpoint` wide — 874 pt on an iPhone 18 Pro, 956 pt
/// on a Pro Max, 951 pt unfolded on the Duo. The tour rotates the app, then
/// asserts **by geometry** that the layout really became two columns — the next
/// window card sits to the right of the answer card instead of below it — and
/// that the four tab labels and the answer survive the rotation.
///
/// No device width is hard-coded: it reads the same breakpoint the app uses.
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
        // The persisted pair is whatever the previous tour left (the AX tour
        // ends on Surf at Arcachon-Eyrac, which has no verdict card at all).
        // A known spot and activity make the answer card deterministic.
        selectSpot(named: "Pointe de Grave", in: app)
        selectActivity(named: "Balade", in: app)

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
        assertSingleColumn(answer: answer, windowCard: windowCard, in: app)

        rotate(to: .landscapeLeft, in: app)
        XCTAssertTrue(
            app.staticTexts["app.title"].waitForExistence(timeout: 10),
            "Home must still be on screen after rotation")

        assertTabLabels(in: app)
        XCTAssertTrue(answer.waitForExistence(timeout: 10), "the answer card left the screen")
        XCTAssertTrue(windowCard.waitForExistence(timeout: 10))
        assertTwoColumns(answer: answer, windowCard: windowCard, in: app)
        attachScreenshot(named: "duo-landscape-home", in: app)

        // The wide spot detail is reachable from the same wide window.
        openSpotDetail(in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label BEGINSWITH %@", "Marée"))
                .firstMatch.waitForExistence(timeout: 10),
            "the tide chart card must render in the wide window")
        attachScreenshot(named: "duo-landscape-spot-detail", in: app)
    }

    // MARK: - Geometry

    /// The phone shape: a tall window, one column, the next window card on the
    /// leading edge and below the answer.
    private func assertSingleColumn(
        answer: XCUIElement,
        windowCard: XCUIElement,
        in app: XCUIApplication)
    {
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(window.height, window.width, "portrait is the tall window")
        XCTAssertLessThan(
            windowCard.frame.minX,
            window.midX,
            "single column: the next window card starts on the leading edge")
        XCTAssertGreaterThan(
            windowCard.frame.minY,
            answer.frame.minY,
            "single column: the next window card sits below the answer")
    }

    /// The wide shape: any landscape window at or above
    /// `OceanLayout.wideBreakpoint` must put the next window card **beside** the
    /// answer card.
    ///
    /// The window decides, never the device model: an iPhone 18 Pro landscape
    /// (874 pt) and the unfolded Duo (951 pt) both qualify. A landscape window
    /// below the threshold — a small phone — is deliberately the phone layout,
    /// which the portrait branch already covers, so there is nothing to assert
    /// about a second column there.
    private func assertTwoColumns(
        answer: XCUIElement,
        windowCard: XCUIElement,
        in app: XCUIApplication)
    {
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(window.width, window.height, "landscape is the wide window")
        guard window.width >= OceanLayout.wideBreakpoint else { return }
        XCTAssertGreaterThanOrEqual(
            windowCard.frame.minX,
            answer.frame.maxX - 1,
            "two columns: at \(window.width) pt the next window card sits beside the answer card")
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

    /// The answer area is one accessibility element. Its label starts with the
    /// verdict (« Oui, balade. … » / « Non, balade. … »), or with « Données
    /// indisponibles pour » when the demo conditions cannot answer — both are
    /// the answer area, and a missing one is a layout failure either way.
    private func answerCard(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(
                format: "label BEGINSWITH %@ OR label BEGINSWITH %@ OR label BEGINSWITH %@",
                "Oui, ", "Non, ", "Données indisponibles pour"))
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

    /// Picks a spot on the map tab, then comes back to Home. At the default text
    /// size the switcher is two chips; the AX `Menu` branch is not exercised by
    /// this tour (the accessibility tour covers it).
    private func selectSpot(named name: String, in app: XCUIApplication) {
        app.buttons["Spots"].firstMatch.tap()
        waitForLayout()
        let chip = app.buttons[name].firstMatch
        if chip.waitForExistence(timeout: 5), !chip.isSelected {
            chip.tap()
            waitForLayout()
        }
        app.buttons["Maintenant"].firstMatch.tap()
        waitForLayout()
    }

    private func selectActivity(named name: String, in app: XCUIApplication) {
        let chip = app.buttons[name].firstMatch
        if chip.waitForExistence(timeout: 5), !chip.isSelected {
            chip.tap()
            waitForLayout()
        }
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
