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

/// The tile names, derived from the metric identifier: the widget and the app
/// must name « Marée », « Vent », « Houle », « Météo » the same way, and an
/// unknown identifier must not invent a name.
final class WidgetMetricTitleTests: XCTestCase {
    func testKnownMetricsAreNamed() {
        let expected = [
            "tide": "Marée",
            "wind": "Vent",
            "swell": "Houle",
            "weather": "Météo"
        ]
        for (id, title) in expected {
            let metric = WidgetSnapshot.Metric(
                id: id, symbol: "wind", value: "1", caption: "—")
            XCTAssertEqual(metric.title, title)
        }
    }

    func testUnknownMetricHasNoNameRatherThanAGuess() {
        let metric = WidgetSnapshot.Metric(
            id: "pressure", symbol: "gauge", value: "1013", caption: "hPa")
        XCTAssertEqual(metric.title, "")
    }

    /// A snapshot written before the names existed still decodes: the title is
    /// derived, never part of the payload.
    func testMetricDecodesWithoutATitleField() throws {
        let json = """
        {"id":"tide","symbol":"water.waves","value":"3,8 m","caption":"descend"}
        """
        let metric = try JSONDecoder().decode(
            WidgetSnapshot.Metric.self, from: Data(json.utf8))
        XCTAssertEqual(metric.title, "Marée")
    }

    /// The compact caption is optional: a snapshot written before it existed
    /// decodes with `nil`, and the widget then draws the full caption.
    func testMetricDecodesWithoutACompactCaption() throws {
        let json = """
        {"id":"swell","symbol":"water.waves","value":"1,2 m","caption":"période 11 s"}
        """
        let metric = try JSONDecoder().decode(
            WidgetSnapshot.Metric.self, from: Data(json.utf8))
        XCTAssertNil(metric.compactCaption)
        XCTAssertEqual(metric.caption, "période 11 s")
    }

    func testMetricCompactCaptionRoundTrips() throws {
        let metric = WidgetSnapshot.Metric(
            id: "swell",
            symbol: "water.waves",
            value: "0,5 m",
            caption: "période 5 s",
            compactCaption: "pér. 5 s")
        let data = try JSONEncoder().encode(metric)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.Metric.self, from: data)
        XCTAssertEqual(decoded, metric)
        XCTAssertEqual(decoded.compactCaption, "pér. 5 s")
    }
}
