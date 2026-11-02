import XCTest

/// M3 AX5 accessibility tour: one screenshot per primary screen state.
///
/// Run at default and AX5 text sizes via `simctl ui content_size` before
/// `xcodebuild test -only-testing:EstranUITests/AccessibilityTourUITests`.
final class AccessibilityTourUITests: XCTestCase {
    private let activities: [(fileSuffix: String, label: String)] = [
        ("peche", "Pêche à pied"),
        ("surf", "Surf"),
        ("bateau", "Bateau"),
        ("balade", "Balade"),
        ("baignade", "Baignade")
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAccessibilityTourCapturesScreensAndTapTargets() {
        let app = XCUIApplication()
        app.launch()

        // First launch shows the activity picker (Figma frame 03). Capture it,
        // then close it: the rest of the tour drives the tabs underneath.
        dismissActivityPickerIfPresent(in: app)

        XCTAssertTrue(
            app.staticTexts["app.title"].waitForExistence(timeout: 15),
            "Home title must appear before the tour starts")

        attachTapTargetReport(from: app, label: "after-launch")
        captureActivities(in: app)
        captureSpots(in: app)
        captureAlerts(in: app)
        captureSettingsAndPicker(in: app)
        captureSpotDetail(in: app)
    }

    /// The five Home states. The last selection is Surf: a short card keeps the
    /// Spots switcher on screen at AX5.
    private func captureActivities(in app: XCUIApplication) {
        for (index, activity) in activities.enumerated() {
            selectActivity(named: activity.label, in: app)
            // Let the glass selection finish its animation: a mid-transition
            // frame shows the previous chip as selected and reads as a defect.
            waitForLayout(in: app)
            scrollToTop(in: app)
            let shotName = String(format: "%02d-home-%@", index + 1, activity.fileSuffix)
            attachScreenshot(named: shotName, in: app)
        }

        selectActivity(named: "Surf", in: app)
        waitForLayout(in: app)
    }

    private func captureSpots(in app: XCUIApplication) {
        app.tabBars.buttons["Spots"].tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

        selectSpot(named: "Pointe de Grave", in: app)
        attachScreenshot(named: "06-spots-pointe-de-grave", in: app)
        attachTapTargetReport(from: app, label: "spots-pointe-de-grave")

        selectSpot(named: "Arcachon-Eyrac", in: app)
        attachScreenshot(named: "07-spots-arcachon-eyrac", in: app)
        attachTapTargetReport(from: app, label: "spots-arcachon-eyrac")
    }

    private func captureAlerts(in app: XCUIApplication) {
        app.tabBars.buttons["Alertes"].tap()
        attachScreenshot(named: "08-alertes", in: app)
        attachTapTargetReport(from: app, label: "alertes")
    }

    private func captureSettingsAndPicker(in app: XCUIApplication) {
        app.tabBars.buttons["Réglages"].tap()
        attachScreenshot(named: "09-reglages", in: app)
        attachTapTargetReport(from: app, label: "reglages")

        // The picker is reachable once onboarding is done. Opening it from
        // Réglages keeps the frame-03 evidence on every run, whether or not this
        // launch was the first one.
        let activityRow = app.staticTexts["Activité"]
        guard activityRow.waitForExistence(timeout: 3) else { return }
        activityRow.tap()
        guard app.staticTexts["Tu fais quoi ?"].waitForExistence(timeout: 5) else { return }
        waitForLayout(in: app)
        attachScreenshot(named: "12-activite-reglages", in: app)
        app.buttons["Terminer"].firstMatch.tap()
        waitForLayout(in: app)
    }

    /// Frame 02: the spot detail, opened from the map card.
    private func captureSpotDetail(in app: XCUIApplication) {
        app.tabBars.buttons["Spots"].tap()
        let detail = app.buttons["Voir le détail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "Spot detail entry missing")
        detail.tap()
        XCTAssertTrue(
            app.staticTexts["Marée"].waitForExistence(timeout: 10),
            "Spot detail chart card missing")
        waitForLayout(in: app)
        attachScreenshot(named: "10-detail-spot", in: app)
        attachTapTargetReport(from: app, label: "detail-spot")

        app.swipeUp()
        waitForLayout(in: app)
        attachScreenshot(named: "11-detail-spot-bas", in: app)
    }

    // MARK: - Frame 03

    /// The first-launch picker is a sheet; it only exists before the group
    /// preference is written, so the tour captures it when present and moves on
    /// when not (second run, or a device that already chose).
    private func dismissActivityPickerIfPresent(in app: XCUIApplication) {
        let title = app.staticTexts["Tu fais quoi ?"]
        guard title.waitForExistence(timeout: 8) else { return }
        waitForLayout(in: app)
        attachScreenshot(named: "00-activite", in: app)
        attachTapTargetReport(from: app, label: "activite")
        app.buttons["Terminer"].firstMatch.tap()
        waitForLayout(in: app)
    }

    // MARK: - Navigation helpers

    /// Waits for the tap animation and the layout pass that follows it.
    private func waitForLayout(in _: XCUIApplication) {
        Thread.sleep(forTimeInterval: 0.9)
    }

    /// Scrolls Home back to its top so every capture shows the same frame
    /// start. `openMenu` may have scrolled to reach the picker at AX5.
    private func scrollToTop(in app: XCUIApplication) {
        let title = app.staticTexts["app.title"]
        for _ in 0 ..< 4 where !title.isHittable {
            app.swipeDown()
        }
        waitForLayout(in: app)
    }

    private func selectActivity(named label: String, in app: XCUIApplication) {
        if app.buttons["Activité"].waitForExistence(timeout: 2) {
            let menuButton = app.buttons["Activité"]
            if (menuButton.value as? String) == label {
                return
            }
            openMenu(menuButton, in: app)
            let item = app.menuItems[label]
            if item.waitForExistence(timeout: 3) {
                item.tap()
            } else {
                let fallback = app.buttons[label]
                XCTAssertTrue(fallback.waitForExistence(timeout: 5), "Menu item \(label) missing at AX sizes")
                fallback.tap()
            }
            return
        }

        let chip = app.buttons[label]
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "Activity chip \(label) missing")
        if chip.isSelected {
            return
        }
        tapWhenObstructed(chip, in: app)
    }

    private func selectSpot(named spotName: String, in app: XCUIApplication) {
        if app.buttons["Choisir un spot"].waitForExistence(timeout: 2) {
            let menuButton = app.buttons["Choisir un spot"]
            if (menuButton.value as? String) == spotName {
                return
            }
            openMenu(menuButton, in: app)
            let item = app.menuItems[spotName]
            if item.waitForExistence(timeout: 3) {
                item.tap()
            } else {
                let fallback = app.buttons[spotName]
                XCTAssertTrue(fallback.waitForExistence(timeout: 5), "Spot menu item \(spotName) missing")
                fallback.tap()
            }
            return
        }

        let chip = app.buttons[spotName]
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "Spot chip \(spotName) missing")
        if chip.isSelected {
            return
        }
        tapWhenObstructed(chip, in: app)
    }

    private func openMenu(_ menuButton: XCUIElement, in app: XCUIApplication) {
        if !menuButton.isHittable {
            // At AX5 the menu sits below the fold: bring it into view before
            // tapping, instead of guessing a coordinate off-screen.
            app.swipeUp()
        }
        if menuButton.isHittable {
            menuButton.tap()
        } else {
            // Coordinate tap avoids XCTest scroll-to-visible on controls pinned under the tab bar.
            menuButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            if app.menuItems.firstMatch.waitForExistence(timeout: 1) {
                return
            }
            menuButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    /// Taps without XCTest's scroll-to-visible pass when AX layouts push controls near the tab bar.
    private func tapWhenObstructed(_ element: XCUIElement, in _: XCUIApplication) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    // MARK: - Evidence attachments

    private func attachScreenshot(named name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Records every tappable element's accessibility frame (points) for the AX5 audit.
    private func attachTapTargetReport(from app: XCUIApplication, label: String) {
        let minimum: CGFloat = 44
        var lines: [String] = [
            "Tap target audit (\(label))",
            "Measurement: XCUIElement.frame in accessibility coordinates (points).",
            "Minimum required: \(Int(minimum))×\(Int(minimum)) pt.",
            ""
        ]

        var violations: [String] = []
        let queries: [XCUIElementQuery] = [
            app.buttons,
            app.tabBars.buttons,
            app.switches,
            app.links
        ]
        for query in queries {
            for element in query.allElementsBoundByIndex {
                guard element.exists else { continue }
                let frame = element.frame
                guard frame.width > 0, frame.height > 0 else { continue }

                let name = element.label.isEmpty ? element.identifier : element.label
                let sizeLine = String(
                    format: "%@ — %.1f×%.1f pt @ (%.0f, %.0f)",
                    name, frame.width, frame.height, frame.origin.x, frame.origin.y)
                lines.append(sizeLine)
                if frame.width < minimum || frame.height < minimum {
                    violations.append(sizeLine)
                }
            }
        }

        if !violations.isEmpty {
            lines.append("")
            lines.append("Below minimum (\(Int(minimum)) pt):")
            lines.append(contentsOf: violations)
        } else {
            lines.append("")
            lines.append("No hittable control below \(Int(minimum)) pt in this snapshot.")
        }

        let attachment = XCTAttachment(string: lines.joined(separator: "\n"))
        attachment.name = "tap-targets-\(label)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
