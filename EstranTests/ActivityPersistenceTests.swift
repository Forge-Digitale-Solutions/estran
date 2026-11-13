@testable import Estran
import EstranCore
import XCTest

/// W-PERSIST — the activity the user picked survives a relaunch, exactly like
/// the spot already did.
///
/// The storage contract first (round-trip, missing value, value from another
/// build), then the `AppModel` behaviour: restored before the first decision, a
/// spot/activity combination the spot does not offer kept as is, and the widget
/// « Automatique » path still reading the app's activity.
final class ActivityPersistenceTests: XCTestCase {
    // MARK: - Storage

    func testStoredActivityRoundTrips() throws {
        let defaults = try makeDefaults()
        let storage = ActivitySelectionStorage(defaults: defaults)

        storage.save(.boating)

        XCTAssertEqual(
            ActivitySelectionStorage(defaults: defaults).load(), .boating,
            "a fresh storage instance reads the value back, like a relaunch")
    }

    func testMissingActivityFallsBackToTheDefault() throws {
        let defaults = try makeDefaults()

        XCTAssertEqual(
            ActivitySelectionStorage(defaults: defaults).load(),
            ActivitySelectionStorage.fallback)
        XCTAssertEqual(ActivitySelectionStorage.fallback, .shoreFishing)
    }

    func testUnknownStoredActivityFallsBackToTheDefault() throws {
        let defaults = try makeDefaults()
        // An activity removed from `Activity.allCases` by a later build.
        defaults.set("yoga", forKey: ActivitySelectionStorage.key)

        XCTAssertEqual(
            ActivitySelectionStorage(defaults: defaults).load(),
            ActivitySelectionStorage.fallback,
            "a stale identifier is never mapped to another activity")
    }

    func testClearingTheActivityFallsBackToTheDefault() throws {
        let defaults = try makeDefaults()
        let storage = ActivitySelectionStorage(defaults: defaults)
        storage.save(.walking)

        storage.clear()

        XCTAssertEqual(storage.load(), ActivitySelectionStorage.fallback)
    }

    // MARK: - AppModel

    @MainActor
    func testRelaunchRestoresTheChosenActivityBeforeTheFirstDecision() async throws {
        let defaults = try makeDefaults()
        let first = makeApp(defaults: defaults)
        await first.reload()
        first.select(activity: .boating)

        XCTAssertEqual(
            defaults.string(forKey: ActivitySelectionStorage.key),
            Activity.boating.rawValue,
            "the choice is written on every user change")

        // A second launch: a new AppModel over the same App Group.
        let relaunched = makeApp(defaults: defaults)
        XCTAssertEqual(
            relaunched.activity, .boating,
            "restored in init, before any decision is computed")
        XCTAssertNil(relaunched.decision, "nothing is decided before the first reload")

        await relaunched.reload()
        XCTAssertEqual(relaunched.decision?.activity, .boating)
    }

    @MainActor
    func testRestoredActivityIsNotOverwrittenByTheDefaultOnFirstDecision() async throws {
        let defaults = try makeDefaults()
        ActivitySelectionStorage(defaults: defaults).save(.swimming)

        let app = makeApp(defaults: defaults)
        await app.reload()

        XCTAssertEqual(app.activity, .swimming)
        XCTAssertEqual(
            defaults.string(forKey: ActivitySelectionStorage.key),
            Activity.swimming.rawValue,
            "the restored value stays in storage")
    }

    @MainActor
    func testRestoredNotOfferedCombinationIsKeptNotReplaced() async throws {
        let defaults = try makeDefaults()
        // Surf at Arcachon-Eyrac: a valid stored pair the spot does not offer.
        SpotSelectionStorage(defaults: defaults).save(SpotCatalog.arcachonEyrac.id)
        ActivitySelectionStorage(defaults: defaults).save(.surfing)

        let app = makeApp(defaults: defaults)
        XCTAssertEqual(app.activity, .surfing, "the stored activity is kept as is")

        await app.reload()

        XCTAssertEqual(app.selectedSpot.id, SpotCatalog.arcachonEyrac.id)
        XCTAssertEqual(app.activity, .surfing, "never silently switched to another verdict")
        XCTAssertTrue(app.isActivityNotOffered)
        XCTAssertNil(app.decision)
        XCTAssertTrue(app.slots.isEmpty)
        XCTAssertEqual(
            ActivitySelectionStorage(defaults: defaults).load(), .surfing,
            "the stored choice survives the not-offered card")
    }

    @MainActor
    func testWidgetDeepLinkPersistsTheActivity() async throws {
        let defaults = try makeDefaults()
        let app = makeApp(defaults: defaults)

        await app.openWidget(spotID: SpotCatalog.arcachonEyrac.id, activity: .boating)

        XCTAssertEqual(app.activity, .boating)
        XCTAssertEqual(ActivitySelectionStorage(defaults: defaults).load(), .boating)
    }

    @MainActor
    func testIntentActivityIsPersistedThroughTheSelectionPath() async throws {
        let defaults = try makeDefaults()
        let app = makeApp(defaults: defaults)
        await app.reload()

        IntentSelectionStorage(defaults: defaults).save(activity: .walking)
        await app.applyIntentSelectionIfNeeded()

        XCTAssertEqual(app.activity, .walking)
        XCTAssertEqual(ActivitySelectionStorage(defaults: defaults).load(), .walking)
    }

    @MainActor
    func testAutomaticWidgetFollowsTheRestoredActivity() async throws {
        let defaults = try makeDefaults()
        ActivitySelectionStorage(defaults: defaults).save(.surfing)

        let app = makeApp(defaults: defaults)
        await app.reload()

        // What the app writes for the widget: the snapshot carries the restored
        // activity, so a widget set to « Automatique » follows it.
        let conditions = try XCTUnwrap(app.store.conditions)
        let snapshot = WidgetSnapshotBuilder.make(
            WidgetSnapshotBuilder.Input(
                conditions: conditions,
                overviews: app.overviews,
                activity: app.activity,
                decision: app.decision,
                timeZone: app.selectedSpot.timezone,
                isSampleData: app.usesSampleData))

        XCTAssertEqual(WidgetSelection.activity(configured: nil, snapshot: snapshot), .surfing)
        XCTAssertEqual(
            WidgetSelection.activity(configured: .boating, snapshot: snapshot), .boating,
            "an explicit widget activity still wins")
    }

    @MainActor
    func testAnUnchangedSelectionWritesNothing() async throws {
        let defaults = try makeDefaults()
        let app = makeApp(defaults: defaults)
        await app.reload()

        // Tapping the already selected chip is not a change: nothing is written,
        // nothing is recomputed.
        app.select(activity: app.activity)

        XCTAssertNil(
            defaults.string(forKey: ActivitySelectionStorage.key),
            "no stored value is invented for a choice the user never made")
    }

    // MARK: - Fixtures

    private func makeDefaults() throws -> UserDefaults {
        let suite = "EstranTests.ActivityPersistence.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock {
            // A fresh instance inside the block: `UserDefaults` is not
            // `Sendable`, so capturing it would send it across actors.
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        }
        return defaults
    }

    @MainActor
    private func makeApp(defaults: UserDefaults) -> AppModel {
        AppModel(
            provider: ActivityPersistenceConditionsProvider(),
            selectionStorage: SpotSelectionStorage(defaults: defaults),
            intentSelection: IntentSelectionStorage(defaults: defaults),
            activityStorage: ActivitySelectionStorage(defaults: defaults),
            // No model in tests: the template sentence is the display floor.
            reasonProvider: TemplateReasonProvider())
    }
}

/// Real `Conditions` values, no network and no tide dataset.
private struct ActivityPersistenceConditionsProvider: ConditionsProviding {
    let isSampleData = true

    func conditions(for spot: Spot, at date: Date) async throws -> Conditions {
        Self.conditions(for: spot, at: date)
    }

    func forecast(for spot: Spot, from date: Date, hours: Int) async throws -> [Conditions] {
        (0 ..< max(hours, 1)).map { hour in
            Self.conditions(for: spot, at: date.addingTimeInterval(Double(hour) * 3600))
        }
    }

    private static func conditions(for spot: Spot, at instant: Date) -> Conditions {
        Conditions(
            spot: spot,
            at: instant,
            tide: TideState(
                current: TideEvent(
                    time: instant.addingTimeInterval(-3600),
                    kind: .low,
                    height: 0.88),
                next: TideEvent(
                    time: instant.addingTimeInterval(3 * 3600),
                    kind: .high,
                    height: 4.2),
                coefficient: 85,
                curve: [TidePoint(time: instant.addingTimeInterval(-3600), height: 0.88)]),
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
