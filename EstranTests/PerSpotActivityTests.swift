@testable import Estran
import EstranCore
import XCTest

/// Per-spot activities end to end: the snapshot builder, the AppModel scanner
/// and the Siri intent all agree that Eyrac does not offer surf.
final class PerSpotActivityTests: XCTestCase {
    /// Fixed instant, so a decision never depends on the clock.
    private static let at = Date(timeIntervalSince1970: 1_793_000_000)

    // MARK: - Snapshot builder

    func testEyracSnapshotDropsSurfFromEveryLine() {
        let spot = SpotCatalog.arcachonEyrac
        let conditions = Self.stubConditions(spot: spot, at: Self.at)
        // The overviews include surf on purpose: the builder is the last line of
        // defence and must filter it out for a spot that does not offer it.
        let overviews = Activity.allCases.map { activity in
            ActivityOverview(
                activity: activity,
                decision: Self.decision(activity: activity, spot: spot),
                current: nil,
                upcoming: nil)
        }

        let snapshot = WidgetSnapshotBuilder.make(
            WidgetSnapshotBuilder.Input(
                conditions: conditions,
                overviews: overviews,
                activity: .surfing,
                decision: nil,
                timeZone: spot.timezone,
                isSampleData: false))

        XCTAssertTrue(snapshot.isNotOffered)
        XCTAssertFalse(snapshot.isGo, "not offered is never a Oui")
        XCTAssertFalse(snapshot.isUnavailable, "not offered is never missing data")
        XCTAssertFalse(snapshot.lines.contains { $0.activity == .surfing })
        XCTAssertEqual(
            Set(snapshot.lines.map(\.activity)),
            Set([.shoreFishing, .boating, .walking, .swimming]),
            "four lines at Eyrac, no blank row")
        XCTAssertTrue(snapshot.answer.contains("Pas de surf"))
    }

    func testPointeDeGraveSnapshotStillOffersSurf() {
        let spot = SpotCatalog.pointeDeGrave
        let conditions = Self.stubConditions(spot: spot, at: Self.at)
        let overviews = Activity.allCases.map { activity in
            ActivityOverview(
                activity: activity,
                decision: Self.decision(activity: activity, spot: spot),
                current: nil,
                upcoming: nil)
        }

        let snapshot = WidgetSnapshotBuilder.make(
            WidgetSnapshotBuilder.Input(
                conditions: conditions,
                overviews: overviews,
                activity: .surfing,
                decision: Self.decision(activity: .surfing, spot: spot),
                timeZone: spot.timezone,
                isSampleData: false))

        XCTAssertFalse(snapshot.isNotOffered)
        XCTAssertTrue(snapshot.lines.contains { $0.activity == .surfing })
    }

    // MARK: - Scanner (AppModel)

    @MainActor
    func testAppModelNeverComputesSurfAtEyrac() async throws {
        let fixture = try Self.makeApp()
        await fixture.app.select(spot: SpotCatalog.arcachonEyrac)

        XCTAssertFalse(fixture.app.overviews.contains { $0.activity == .surfing })
        XCTAssertTrue(fixture.app.overviews.contains { $0.activity == .boating })
        XCTAssertFalse(fixture.app.unavailableActivities.contains(.surfing))

        // Selecting surf inside the Bassin is a neutral state, never a verdict.
        fixture.app.select(activity: .surfing)
        XCTAssertTrue(fixture.app.isActivityNotOffered)
        XCTAssertNil(fixture.app.decision)
        XCTAssertTrue(fixture.app.slots.isEmpty)
    }

    // MARK: - Intent

    func testSiriSurfAtEyracAnswersTheNotOfferedSentence() {
        let intent = AnswerIntent(
            spot: SpotEntity(spot: SpotCatalog.arcachonEyrac),
            activity: ActivityEntity(activity: .surfing))

        let text = intent.resolvedText(for: nil)

        XCTAssertEqual(
            text,
            "Pas de surf à Arcachon-Eyrac. Le surf, c'est côté océan : Cap Ferret ou la Salie.")
        XCTAssertFalse(text.contains("Oui"))
        XCTAssertFalse(text.contains("Non"))
    }

    // MARK: - Fixtures

    private struct Fixture {
        let app: AppModel
    }

    @MainActor
    private static func makeApp() throws -> Fixture {
        let suite = "EstranTests.PerSpot.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let app = AppModel(
            provider: StubConditionsProvider(),
            selectionStorage: SpotSelectionStorage(defaults: defaults),
            intentSelection: IntentSelectionStorage(defaults: defaults),
            activityStorage: ActivitySelectionStorage(defaults: defaults),
            reasonProvider: TemplateReasonProvider())
        return Fixture(app: app)
    }

    private static func decision(activity: Activity, spot: Spot) -> GoDecision {
        GoDecision(
            activity: activity,
            spot: spot,
            go: activity != .surfing,
            score: 0.8,
            reason: "Oui",
            reasonSource: .template,
            nextGoodWindow: nil,
            computedAt: at,
            blockers: [])
    }

    static func stubConditions(spot: Spot, at date: Date) -> Conditions {
        Conditions(
            spot: spot,
            at: date,
            tide: TideState(
                current: TideEvent(time: date.addingTimeInterval(-3600), kind: .low, height: 0.88),
                next: TideEvent(time: date.addingTimeInterval(3 * 3600), kind: .high, height: 4.2),
                coefficient: 85,
                curve: [TidePoint(time: date.addingTimeInterval(-3600), height: 0.88)]),
            weather: WeatherNow(
                temperature: 16,
                condition: .partlyCloudy,
                precipitationChance: 0.1,
                cloudCover: 0.4,
                wind: Wind(speed: 12, gust: 20, directionDegrees: 250),
                visibility: 20000),
            swell: Swell(
                waveHeight: 1.2,
                period: 9,
                directionDegrees: 280,
                seaSurfaceTemperature: 17,
                source: .model))
    }
}

/// Deterministic conditions for whatever spot it is asked for, no network.
private struct StubConditionsProvider: ConditionsProviding {
    let isSampleData = true

    func conditions(for spot: Spot, at date: Date) async throws -> Conditions {
        PerSpotActivityTests.stubConditions(spot: spot, at: date)
    }

    func forecast(for spot: Spot, from date: Date, hours: Int) async throws -> [Conditions] {
        (0 ..< max(hours, 1)).map { hour in
            PerSpotActivityTests.stubConditions(spot: spot, at: date.addingTimeInterval(Double(hour) * 3600))
        }
    }
}
