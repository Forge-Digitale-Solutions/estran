import XCTest

/// W-ATTR evidence: the weather attribution and the indicator glossary.
///
/// Three frames, all from the shipped screens:
/// - `attr-reglages`: the Réglages source + Météo sections, with the Apple
///   Weather mark and the « Sources légales » link when WeatherKit answered;
/// - `attr-reglages-glossaire`: « Comprendre les indicateurs », one row per
///   term, scrolled into view;
/// - `attr-detail-footer`: the spot detail footer, where the same credit sits
///   next to the REFMAR line.
///
/// The tour launches with `-liveData` so the credit describes a real provider.
/// It asserts only what must exist without network: the two section titles.
/// Whether Apple or Open-Meteo answered decides which credit is drawn, and the
/// screenshot records that honestly.
final class AttributionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAttributionAndGlossary() {
        let app = XCUIApplication()
        app.launchArguments = ["-liveData"]
        app.launch()
        dismissActivityPickerIfPresent(in: app)

        XCTAssertTrue(
            app.staticTexts["app.title"].waitForExistence(timeout: 20),
            "Home must load before the attribution tour starts")

        captureSettingsAttribution(in: app)
        captureSettingsGlossary(in: app)
        captureDetailFooter(in: app)
    }

    // MARK: - Réglages

    private func captureSettingsAttribution(in app: XCUIApplication) {
        app.tabBars.buttons["Réglages"].tap()
        let header = app.staticTexts["Météo"]
        XCTAssertTrue(header.waitForExistence(timeout: 10), "The Météo section is missing")
        // The Météo section is second on the screen, so it is fully visible
        // without scrolling — a reviewer must find the credit immediately. The
        // glossary below is asserted by the next capture.
        waitForLayout()
        attachScreenshot(named: "attr-reglages", in: app)
    }

    private func captureSettingsGlossary(in app: XCUIApplication) {
        let firstTerm = app.staticTexts["Marée"]
        // The List builds its rows lazily: scroll until the glossary is
        // realised, then until its first entry is clear of the tab bar.
        for _ in 0 ..< 10 where !firstTerm.exists {
            app.swipeUp()
            waitForLayout()
        }
        XCTAssertTrue(
            firstTerm.waitForExistence(timeout: 5),
            "The glossary's first entry is missing")
        scrollIntoView(firstTerm, in: app)
        waitForLayout()
        attachScreenshot(named: "attr-reglages-glossaire", in: app)
    }

    // MARK: - Spot detail

    private func captureDetailFooter(in app: XCUIApplication) {
        scrollToTop(in: app)
        app.tabBars.buttons["Spots"].tap()
        let detail = app.buttons["Voir le détail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "Spot detail entry missing")
        detail.tap()
        XCTAssertTrue(
            app.staticTexts["Marée"].waitForExistence(timeout: 10),
            "Spot detail chart card missing")

        // The footer carries the REFMAR line and the weather credit; scroll
        // until one of the two legal links is on screen.
        for _ in 0 ..< 8 {
            if app.links.firstMatch.exists, app.links.firstMatch.isHittable {
                break
            }
            app.swipeUp()
            waitForLayout()
        }
        waitForLayout()
        attachScreenshot(named: "attr-detail-footer", in: app)
    }

    // MARK: - Helpers

    /// Scrolls until `element` is on screen and clear of the floating tab bar,
    /// then stops: overshooting would hide the part that matters.
    private func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication) {
        let window = app.windows.firstMatch.frame
        for _ in 0 ..< 8 {
            guard element.exists else {
                app.swipeUp()
                waitForLayout()
                continue
            }
            if element.frame.minY > 90, element.frame.maxY < window.height - 140 {
                return
            }
            app.swipeUp()
            waitForLayout()
        }
    }

    private func scrollToTop(in app: XCUIApplication) {
        for _ in 0 ..< 10 where !app.tabBars.buttons["Spots"].exists {
            app.swipeDown()
            waitForLayout()
        }
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
