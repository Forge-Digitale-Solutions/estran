@testable import EstranCore
import XCTest

/// The v1 catalog is a product statement: **two spots, both gauged**.
final class SpotCatalogTests: XCTestCase {
    func testV1ShipsExactlyTwoGaugedSpots() {
        XCTAssertEqual(SpotCatalog.v1.count, 2)
        XCTAssertEqual(Set(SpotCatalog.v1.map(\.id)), ["pointe-de-grave", "arcachon-eyrac"])
        XCTAssertTrue(SpotCatalog.v1.allSatisfy { $0.validation == .gauged })
        XCTAssertTrue(SpotCatalog.v1.allSatisfy { $0.correctionStatus == .none })
        XCTAssertTrue(SpotCatalog.v1.allSatisfy(\.uncertainty.isActive))
    }

    func testEverySpotSupportsTheFiveActivities() {
        for spot in SpotCatalog.v1 {
            XCTAssertEqual(spot.supportedActivities, Set(Activity.allCases), spot.id)
            XCTAssertFalse(spot.name.isEmpty)
            XCTAssertEqual(spot.timezone.identifier, "Europe/Paris")
        }
    }

    func testSpotsReferenceTheShippedStations() {
        XCTAssertEqual(SpotCatalog.pointeDeGrave.tideStation.id, "15")
        XCTAssertEqual(SpotCatalog.arcachonEyrac.tideStation.id, "190")
    }

    func testCatalogEnvelopesMatchTheShippedDataset() throws {
        let model = try ShippedTideModel.load()
        for spot in SpotCatalog.v1 {
            let entry = try XCTUnwrap(
                model.spots.first { $0.id == spot.id },
                "the shipped dataset has no entry for \(spot.id)")
            XCTAssertEqual(entry.stationId, spot.tideStation.id)
            XCTAssertEqual(entry.uncertainty.timeMinutes, spot.uncertainty.timeMinutes)
            XCTAssertEqual(entry.uncertainty.heightMeters, spot.uncertainty.heightMeters)
            XCTAssertEqual(entry.swimmingRange, spot.swimmingRange)
        }
    }

    func testUnknownOrMissingIdentifierFallsBackToTheDefault() {
        XCTAssertEqual(SpotCatalog.spot(id: "pointe-de-grave")?.id, "pointe-de-grave")
        XCTAssertNil(SpotCatalog.spot(id: "andernos"))
        XCTAssertEqual(SpotCatalog.spot(id: "andernos").id, SpotCatalog.defaultSpot.id)
        XCTAssertEqual(SpotCatalog.spot(id: nil).id, SpotCatalog.defaultSpot.id)
    }

    func testModelLabelNeverClaimsAMeasurement() {
        for spot in SpotCatalog.v1 {
            XCTAssertEqual(spot.modelLabel, "modèle local — station \(spot.tideStation.id)")
            XCTAssertFalse(spot.modelLabel.contains("mesure"))
        }
    }
}
