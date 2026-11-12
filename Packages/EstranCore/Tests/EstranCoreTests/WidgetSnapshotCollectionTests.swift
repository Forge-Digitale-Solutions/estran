@testable import EstranCore
import Foundation
import XCTest

/// W-WIDGETCONF — the per-spot snapshot collection and its legacy fallback.
final class WidgetSnapshotCollectionTests: XCTestCase {
    // MARK: - Per-spot round-trip

    func testCollectionRoundTripsBothSpots() throws {
        let directory = Self.temporaryDirectory()
        let pointe = Self.snapshot(spotID: "pointe-de-grave", name: "Pointe de Grave")
        let eyrac = Self.snapshot(spotID: "arcachon-eyrac", name: "Arcachon-Eyrac")

        try WidgetSnapshot.saveCollection([pointe, eyrac], in: directory)

        XCTAssertEqual(
            WidgetSnapshot.load(forSpotID: "pointe-de-grave", from: directory),
            pointe)
        XCTAssertEqual(
            WidgetSnapshot.load(forSpotID: "arcachon-eyrac", from: directory),
            eyrac)
        XCTAssertNil(WidgetSnapshot.load(forSpotID: "unknown", from: directory))
    }

    func testCollectionReplacesItsPreviousContents() throws {
        let directory = Self.temporaryDirectory()
        let first = Self.snapshot(spotID: "pointe-de-grave", name: "Pointe de Grave")
        let second = Self.snapshot(spotID: "arcachon-eyrac", name: "Arcachon-Eyrac")

        try WidgetSnapshot.saveCollection([first], in: directory)
        try WidgetSnapshot.saveCollection([second], in: directory)

        XCTAssertEqual(
            WidgetSnapshot.load(forSpotID: "arcachon-eyrac", from: directory),
            second)
        // `saveCollection` writes exactly the snapshots it is given; callers
        // that want to keep other spots merge first (the app does).
        XCTAssertNil(WidgetSnapshot.load(forSpotID: "pointe-de-grave", from: directory))
    }

    func testSaveCollectionWithoutAContainerThrows() {
        let snapshot = Self.snapshot(spotID: "pointe-de-grave", name: "Pointe de Grave")
        XCTAssertThrowsError(try WidgetSnapshot.saveCollection([snapshot], in: nil)) { error in
            XCTAssertEqual(error as? WidgetSnapshotError, .containerUnavailable)
        }
    }

    // MARK: - Backward compatibility (legacy single file)

    func testLegacySingleFileIsHonouredForItsOwnSpot() throws {
        let directory = Self.temporaryDirectory()
        let pointe = Self.snapshot(spotID: "pointe-de-grave", name: "Pointe de Grave")

        // An old app wrote the single file, not the collection.
        try pointe.save(in: directory)

        XCTAssertEqual(
            WidgetSnapshot.load(forSpotID: "pointe-de-grave", from: directory),
            pointe)
    }

    func testLegacySingleFileIsNeverTheOtherSpot() throws {
        let directory = Self.temporaryDirectory()
        try Self.snapshot(spotID: "pointe-de-grave", name: "Pointe de Grave").save(in: directory)

        XCTAssertNil(
            WidgetSnapshot.load(forSpotID: "arcachon-eyrac", from: directory),
            "a single-file snapshot must never be treated as the other spot's value")
    }

    func testCollectionWinsOverTheLegacySingleFile() throws {
        let directory = Self.temporaryDirectory()
        let legacy = Self.snapshot(spotID: "pointe-de-grave", name: "Pointe de Grave", answer: "legacy")
        let fresh = Self.snapshot(spotID: "pointe-de-grave", name: "Pointe de Grave", answer: "fresh")

        try legacy.save(in: directory)
        try WidgetSnapshot.saveCollection([fresh], in: directory)

        XCTAssertEqual(
            WidgetSnapshot.load(forSpotID: "pointe-de-grave", from: directory),
            fresh)
    }

    // MARK: - Fixtures

    private static func snapshot(
        spotID: String,
        name: String,
        answer: String = "13 h 10 à 15 h 40") -> WidgetSnapshot
    {
        WidgetSnapshot(
            updatedAt: Date(timeIntervalSince1970: 1_793_000_000),
            spotID: spotID,
            spotName: name,
            activity: .shoreFishing,
            isGo: true,
            isUnavailable: false,
            answer: answer,
            lines: [
                WidgetSnapshot.ActivityLine(
                    activity: .shoreFishing, isUnavailable: false, isGo: true,
                    answer: answer)
            ],
            metrics: [
                WidgetSnapshot.Metric(id: "wind", symbol: "wind", value: "12", caption: "km/h NE")
            ],
            isSampleData: false)
    }

    private static func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshots-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
