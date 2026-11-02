@testable import Estran
import EstranCore
import XCTest

/// The App Group path the widgets read from, checked in the app process (the
/// only place where the group container is really provisioned).
final class WidgetSnapshotStorageTests: XCTestCase {
    func testTheAppWritesASnapshotTheWidgetCanRead() throws {
        let container = try XCTUnwrap(
            WidgetSnapshot.containerURL(),
            "the App Group container must be reachable from the app")

        let snapshot = WidgetSnapshot(
            updatedAt: Date(),
            spotID: "arcachon-eyrac",
            spotName: "Arcachon-Eyrac",
            activity: .shoreFishing,
            isGo: true,
            isUnavailable: false,
            answer: "13 h 10 à 15 h 40")

        try snapshot.save(in: container)
        let loaded = try XCTUnwrap(WidgetSnapshot.load(from: container))

        // JSON stores the instant as a Double number of seconds: compare with a
        // sub-second tolerance, not with `==` on two `Date()` values.
        XCTAssertEqual(
            loaded.updatedAt.timeIntervalSince1970,
            snapshot.updatedAt.timeIntervalSince1970,
            accuracy: 0.001)
        XCTAssertEqual(loaded.spotName, snapshot.spotName)
        XCTAssertEqual(loaded.answer, snapshot.answer)
        XCTAssertEqual(loaded.activity, snapshot.activity)
        XCTAssertEqual(loaded.isGo, snapshot.isGo)
    }

    func testTheBuilderNeverTurnsSwimmingIntoAGo() throws {
        let spot = SpotCatalog.arcachonEyrac
        let conditions = Conditions(
            spot: spot,
            at: Date(timeIntervalSince1970: 1_793_000_000),
            tide: TideState(current: nil, next: nil, coefficient: 80, curve: []),
            weather: WeatherNow(
                temperature: 18,
                condition: .clear,
                precipitationChance: 0,
                cloudCover: 0.2,
                wind: Wind(speed: 12, gust: 18, directionDegrees: 250),
                visibility: 20000),
            swell: Swell(
                waveHeight: 0.4,
                period: 3,
                directionDegrees: 250,
                seaSurfaceTemperature: nil,
                source: .windSeaEstimate))

        let decision = DecisionEngine().decide(
            activity: .swimming,
            conditions: conditions)
        let overview = ActivityOverview(
            activity: .swimming,
            decision: decision,
            current: nil,
            upcoming: nil)

        let snapshot = WidgetSnapshotBuilder.make(
            WidgetSnapshotBuilder.Input(
                conditions: conditions,
                overviews: [overview],
                activity: .swimming,
                decision: decision,
                timeZone: spot.timezone,
                isSampleData: false))

        XCTAssertFalse(snapshot.isGo, "swimming is never a Oui on any surface")
        XCTAssertNotNil(snapshot.swimmingAdvisory)
        let line = try XCTUnwrap(snapshot.lines.first)
        XCTAssertFalse(line.isGo)
        XCTAssertEqual(line.activity, .swimming)
        XCTAssertFalse(line.answer.isEmpty, "the row always shows the level or the gap")
    }
}
