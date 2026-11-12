@testable import EstranCore
import Foundation
import XCTest

/// W-WIDGETCONF — resolving a widget's « Automatique » selection.
final class WidgetSelectionTests: XCTestCase {
    func testAutomaticFollowsTheSelectedSpot() {
        XCTAssertEqual(
            WidgetSelection.spot(configuredID: nil, selectedID: "arcachon-eyrac"),
            SpotCatalog.arcachonEyrac)
        XCTAssertEqual(
            WidgetSelection.spot(configuredID: nil, selectedID: "pointe-de-grave"),
            SpotCatalog.pointeDeGrave)
    }

    func testConfiguredSpotWinsOverTheSelection() {
        XCTAssertEqual(
            WidgetSelection.spot(configuredID: "pointe-de-grave", selectedID: "arcachon-eyrac"),
            SpotCatalog.pointeDeGrave)
    }

    func testUnknownConfiguredSpotFallsBackToTheSelection() {
        XCTAssertEqual(
            WidgetSelection.spot(configuredID: "cap-ferret", selectedID: "arcachon-eyrac"),
            SpotCatalog.arcachonEyrac)
    }

    func testNoSelectionFallsBackToTheDefaultSpot() {
        XCTAssertEqual(
            WidgetSelection.spot(configuredID: nil, selectedID: nil),
            SpotCatalog.defaultSpot)
    }

    func testAutomaticActivityFollowsTheSnapshot() {
        let snapshot = WidgetSnapshot(
            updatedAt: Date(),
            spotID: "pointe-de-grave",
            spotName: "Pointe de Grave",
            activity: .boating,
            isGo: true,
            isUnavailable: false,
            answer: "15 h 00 à 17 h 00")
        XCTAssertEqual(
            WidgetSelection.activity(configured: nil, snapshot: snapshot),
            .boating)
    }

    func testConfiguredActivityWinsOverTheSnapshot() {
        let snapshot = WidgetSnapshot(
            updatedAt: Date(),
            spotID: "pointe-de-grave",
            spotName: "Pointe de Grave",
            activity: .boating,
            isGo: true,
            isUnavailable: false,
            answer: "15 h 00 à 17 h 00")
        XCTAssertEqual(
            WidgetSelection.activity(configured: .surfing, snapshot: snapshot),
            .surfing)
    }

    /// The options provider's filter: Eyrac offers four activities, never surf.
    func testOfferedActivitiesAtEyracExcludeSurf() {
        let offered = WidgetSelection.offeredActivities(at: SpotCatalog.arcachonEyrac)
        XCTAssertEqual(
            Set(offered),
            Set([.shoreFishing, .boating, .walking, .swimming]))
        XCTAssertFalse(offered.contains(.surfing))
    }

    func testOfferedActivitiesAtPointeDeGraveIncludeSurf() {
        let offered = WidgetSelection.offeredActivities(at: SpotCatalog.pointeDeGrave)
        XCTAssertTrue(offered.contains(.surfing))
        XCTAssertEqual(offered.count, 5)
    }
}
