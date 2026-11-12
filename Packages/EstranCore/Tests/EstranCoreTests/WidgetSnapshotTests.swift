@testable import EstranCore
import Foundation
import XCTest

/// M5 — the snapshot the app hands to the widgets.
final class WidgetSnapshotTests: XCTestCase {
    func testRoundTripThroughTheSharedContainer() throws {
        let directory = Self.temporaryDirectory()
        let snapshot = Self.snapshot()

        try snapshot.save(in: directory)
        let loaded = WidgetSnapshot.load(from: directory)

        XCTAssertEqual(loaded, snapshot)
    }

    func testMissingContainerReturnsNil() {
        XCTAssertNil(WidgetSnapshot.load(from: Self.temporaryDirectory()))
    }

    func testSaveWithoutAContainerThrows() {
        XCTAssertThrowsError(try Self.snapshot().save(in: nil)) { error in
            XCTAssertEqual(error as? WidgetSnapshotError, .containerUnavailable)
        }
    }

    func testFreshSnapshotIsNotStale() {
        let snapshot = WidgetSnapshot(
            updatedAt: Date(),
            spotID: "pointe-de-grave",
            spotName: "Pointe de Grave",
            activity: .shoreFishing,
            isGo: true,
            isUnavailable: false,
            answer: "13 h 10 à 15 h 40")
        XCTAssertFalse(snapshot.isStale)
    }

    func testOldSnapshotIsStale() {
        let snapshot = WidgetSnapshot(
            updatedAt: Date().addingTimeInterval(-3 * 60 * 60),
            spotID: "pointe-de-grave",
            spotName: "Pointe de Grave",
            activity: .shoreFishing,
            isGo: true,
            isUnavailable: false,
            answer: "13 h 10 à 15 h 40")
        XCTAssertTrue(snapshot.isStale)
    }

    /// The widget must never receive a swimming line that could read as `Oui`.
    func testSwimmingLineCarriesItsLevelAndWarning() throws {
        let directory = Self.temporaryDirectory()
        try Self.snapshot().save(in: directory)
        let loaded = try XCTUnwrap(WidgetSnapshot.load(from: directory))
        let swimming = try XCTUnwrap(loaded.lines.first { $0.activity == .swimming })

        XCTAssertFalse(swimming.isGo)
        XCTAssertEqual(swimming.swimmingLevel, .moderate)
        XCTAssertNotNil(swimming.warning)
    }

    func testUnavailableLineIsNotAVerdict() throws {
        let directory = Self.temporaryDirectory()
        try Self.snapshot().save(in: directory)
        let loaded = try XCTUnwrap(WidgetSnapshot.load(from: directory))
        let unavailable = try XCTUnwrap(loaded.lines.first { $0.activity == .surfing })

        XCTAssertTrue(unavailable.isUnavailable)
        XCTAssertFalse(unavailable.isGo)
        XCTAssertEqual(unavailable.answer, "Données indisponibles")
    }

    // MARK: - Caution

    /// The Live Activity and Siri read the selected activity's caution through
    /// this property: the line the app already composed, never a new string.
    func testTheSelectedActivitysCautionComesFromItsOwnLine() {
        let snapshot = WidgetSnapshot(
            updatedAt: Date(),
            spotID: "arcachon-eyrac",
            spotName: "Arcachon-Eyrac",
            activity: .boating,
            isGo: true,
            isUnavailable: false,
            answer: "13 h 10 à 15 h 40",
            lines: [
                WidgetSnapshot.ActivityLine(
                    activity: .boating, isUnavailable: false, isGo: true,
                    answer: "13 h 10 à 15 h 40",
                    warning: ActivityCaution.boatingPasses)
            ])

        XCTAssertEqual(snapshot.caution, ActivityCaution.boatingPasses)
    }

    /// Swimming's advisory already carries the baïnes warning: doubling it on
    /// the card or in Siri would bury the risk level.
    func testSwimmingNeverExposesACaution() {
        let snapshot = WidgetSnapshot(
            updatedAt: Date(),
            spotID: "arcachon-eyrac",
            spotName: "Arcachon-Eyrac",
            activity: .swimming,
            isGo: false,
            isUnavailable: false,
            answer: "Courants de marée estimés : modérés",
            lines: [
                WidgetSnapshot.ActivityLine(
                    activity: .swimming, isUnavailable: false, isGo: false,
                    answer: "Courants de marée estimés : modérés",
                    warning: "Baïnes et courants dangereux toute l'année.",
                    swimmingLevel: .moderate)
            ])

        XCTAssertNil(snapshot.caution)
    }

    func testNoLineOrAnEmptyWarningMeansNoCaution() {
        let withoutLine = WidgetSnapshot(
            updatedAt: Date(),
            spotID: "arcachon-eyrac",
            spotName: "Arcachon-Eyrac",
            activity: .shoreFishing,
            isGo: true,
            isUnavailable: false,
            answer: "13 h 10 à 15 h 40")
        XCTAssertNil(withoutLine.caution, "no line, no caution invented")

        let emptyWarning = WidgetSnapshot(
            updatedAt: Date(),
            spotID: "arcachon-eyrac",
            spotName: "Arcachon-Eyrac",
            activity: .shoreFishing,
            isGo: true,
            isUnavailable: false,
            answer: "13 h 10 à 15 h 40",
            lines: [
                WidgetSnapshot.ActivityLine(
                    activity: .shoreFishing, isUnavailable: false, isGo: true,
                    answer: "13 h 10 à 15 h 40",
                    warning: "   ")
            ])
        XCTAssertNil(emptyWarning.caution, "blank copy is not a caution")
    }

    // MARK: - Fixtures

    private static func snapshot() -> WidgetSnapshot {
        WidgetSnapshot(
            updatedAt: Date(timeIntervalSince1970: 1_793_000_000),
            spotID: "arcachon-eyrac",
            spotName: "Arcachon-Eyrac",
            activity: .shoreFishing,
            isGo: true,
            isUnavailable: false,
            answer: "13 h 10 à 15 h 40",
            swimmingAdvisory: SwimmingAdvisory(level: .moderate, region: .bassin),
            lines: [
                WidgetSnapshot.ActivityLine(
                    activity: .shoreFishing, isUnavailable: false, isGo: true,
                    answer: "13 h 10 à 15 h 40"),
                WidgetSnapshot.ActivityLine(
                    activity: .surfing, isUnavailable: true, isGo: false,
                    answer: "Données indisponibles"),
                WidgetSnapshot.ActivityLine(
                    activity: .swimming, isUnavailable: false, isGo: false,
                    answer: "Courants de marée estimés : modérés",
                    warning: "Baïnes et courants dangereux toute l'année.",
                    swimmingLevel: .moderate)
            ],
            metrics: [
                WidgetSnapshot.Metric(
                    id: "wind", symbol: "wind", value: "12", caption: "km/h NE")
            ],
            isSampleData: false)
    }

    private static func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshot-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
