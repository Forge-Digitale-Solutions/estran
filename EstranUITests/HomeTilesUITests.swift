import XCTest

/// W-LOCK — the condition tiles must name what they show.
///
/// Owner feedback on build 5: « 5 m » with a wave and a down arrow, or
/// « 0,5 m / 6 s », meant nothing to a user. Each tile now carries
/// « Marée », « Vent », « Houle », « Météo », so this tour captures the tiles at
/// both spots (Home), then the chart card and the metric tiles on the spot
/// detail. It is run at the default text size and at AX5 (`simctl ui
/// content_size`), the same two runs as `AccessibilityTourUITests`.
final class HomeTilesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHomeAndDetailTilesAreNamed() {
        let app = XCUIApplication()
        app.launch()
        dismissActivityPickerIfPresent(in: app)
        XCTAssertTrue(
            app.staticTexts["app.title"].waitForExistence(timeout: 15),
            "Home title must appear before the tour starts")

        captureHomeTiles(spot: "Pointe de Grave", named: "pointe-de-grave", in: app)
        captureHomeTiles(spot: "Arcachon-Eyrac", named: "arcachon-eyrac", in: app)
        captureSpotDetail(in: app)
    }

    // MARK: - Home

    private func captureHomeTiles(
        spot: String,
        named suffix: String,
        in app: XCUIApplication)
    {
        ensureSpot(spot, in: app)

        // At accessibility sizes the tiles sit far below the fold, and XCUITest
        // only exposes what is on screen: scroll until the tile enters the tree,
        // then until it clears the tab bar.
        var tide = tile(named: "Marée", in: app)
        for _ in 0 ..< 8 where !tide.exists {
            app.swipeUp()
            waitForLayout()
            tide = tile(named: "Marée", in: app)
        }
        XCTAssertTrue(tide.waitForExistence(timeout: 5), "tide tile missing")

        let window = app.windows.firstMatch.frame
        for _ in 0 ..< 3 where tide.frame.minY > window.height - 120 {
            app.swipeUp()
            waitForLayout()
        }
        XCTAssertLessThan(
            tide.frame.minY,
            window.height - 80,
            "the tiles never reached the visible area")

        for name in ["Marée", "Vent", "Houle", "Météo"] {
            XCTAssertTrue(
                tile(named: name, in: app).exists,
                "the \(name) tile has no name for VoiceOver either")
        }
        attachScreenshot(named: "wlock-tiles-\(suffix)", in: app)
        // The tab bar minimises on scroll down (iOS 27): bring it back before
        // the next navigation step.
        scrollToTop(in: app)
    }

    private func scrollToTop(in app: XCUIApplication) {
        // At AX5 the page is many screens tall and the tab bar minimises while
        // scrolling down: keep swiping until "Spots" is back in the bar.
        for _ in 0 ..< 10 where !app.tabBars.buttons["Spots"].exists {
            app.swipeDown()
            waitForLayout()
        }
        waitForLayout()
    }

    /// The tile's accessible label is its name, a colon, then the value
    /// (« Marée : 3,8 m, descendante »). The colon also keeps the answer card's
    /// « Marée basse à 13 h 14 » out of the match.
    private func tile(named name: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(
                format: "label BEGINSWITH %@ AND label CONTAINS %@",
                name, " : "))
            .firstMatch
    }

    // MARK: - Spot detail

    private func captureSpotDetail(in app: XCUIApplication) {
        scrollToTop(in: app)
        app.tabBars.buttons["Spots"].tap()
        let detail = app.buttons["Voir le détail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "spot detail entry missing")
        detail.tap()
        XCTAssertTrue(
            app.staticTexts["Marée"].waitForExistence(timeout: 10),
            "spot detail chart card missing")
        waitForLayout()
        attachScreenshot(named: "wlock-detail-maree", in: app)

        app.swipeUp()
        waitForLayout()
        attachScreenshot(named: "wlock-detail-tiles", in: app)
    }

    // MARK: - Navigation helpers

    private func ensureSpot(_ name: String, in app: XCUIApplication) {
        app.tabBars.buttons["Spots"].tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

        if app.buttons["Choisir un spot"].waitForExistence(timeout: 2) {
            let menuButton = app.buttons["Choisir un spot"]
            if (menuButton.value as? String) != name {
                if !menuButton.isHittable {
                    app.swipeUp()
                }
                menuButton.tap()
                let item = app.menuItems[name]
                if item.waitForExistence(timeout: 3) {
                    item.tap()
                } else {
                    app.buttons[name].firstMatch.tap()
                }
            }
        } else {
            let chip = app.buttons[name]
            if chip.waitForExistence(timeout: 5), !chip.isSelected {
                chip.tap()
            }
        }

        app.tabBars.buttons["Maintenant"].tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        waitForLayout()
    }

    private func dismissActivityPickerIfPresent(in app: XCUIApplication) {
        let title = app.staticTexts["Tu fais quoi ?"]
        guard title.waitForExistence(timeout: 8) else { return }
        app.buttons["Terminer"].firstMatch.tap()
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
