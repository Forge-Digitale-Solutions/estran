@testable import Estran
import EstranCore
import Foundation
import XCTest

/// W-FIX3 — an `OpenIntent` hitting a *running* app.
///
/// `OpenSpotIntent` / `OpenActivityIntent` only write to the App Group; a warm
/// `AppModel` never re-reads it on its own, so the card used to keep describing
/// the previous place. These tests drive the app-side hook without the App
/// Intents runtime: the intents' storage is the seam, exactly as the widget
/// tests treat the snapshot file.
@MainActor
final class OpenIntentWarmLaunchTests: XCTestCase {
    // MARK: - Spot

    func testASpotlightSpotHitMovesTheRunningAppAndItsData() async throws {
        let fixture = try makeApp()

        await fixture.app.reload()
        XCTAssertEqual(fixture.app.selectedSpot.id, SpotCatalog.defaultSpot.id)

        // The intent runs while the app is warm: only the App Group changes.
        fixture.spotStorage.save(SpotCatalog.arcachonEyrac.id)
        await fixture.app.applyIntentSelectionIfNeeded()

        XCTAssertEqual(fixture.app.selectedSpot.id, SpotCatalog.arcachonEyrac.id)
        let conditions = try XCTUnwrap(
            fixture.app.store.conditions, "the spot change reloaded the store")
        XCTAssertEqual(conditions.spot.id, SpotCatalog.arcachonEyrac.id)
        let decision = try XCTUnwrap(fixture.app.decision, "the decision follows the new spot")
        XCTAssertEqual(decision.spot.id, SpotCatalog.arcachonEyrac.id)
    }

    func testAForegroundWithoutAPendingSpotHitDoesNotReload() async throws {
        let fixture = try makeApp()

        await fixture.app.reload()
        let loads = fixture.provider.counter.count

        await fixture.app.applyIntentSelectionIfNeeded()

        XCTAssertEqual(
            fixture.provider.counter.count, loads,
            "no intent hit: the app must not refetch and flash a loading card")
        XCTAssertEqual(fixture.app.selectedSpot.id, SpotCatalog.defaultSpot.id)
    }

    // MARK: - Activity

    func testAnActivityHitIsAppliedOnceAndNeverReapplied() async throws {
        let fixture = try makeApp()

        await fixture.app.reload()
        fixture.intentStorage.save(activity: .surfing)
        await fixture.app.applyIntentSelectionIfNeeded()

        XCTAssertEqual(fixture.app.activity, .surfing)
        XCTAssertEqual(fixture.app.decision?.activity, .surfing)
        XCTAssertNil(
            fixture.defaults.string(forKey: IntentSelectionStorage.activityKey),
            "the pending activity is consumed, so a later foreground cannot replay it")

        // The user then picks another activity in the app; coming back to the
        // foreground must keep that choice, not the old Spotlight hit.
        fixture.app.select(activity: .walking)
        await fixture.app.applyIntentSelectionIfNeeded()
        XCTAssertEqual(fixture.app.activity, .walking)
    }

    func testAnActivityHitDoesNotResetAnAlreadySelectedSameActivity() async throws {
        let fixture = try makeApp()

        await fixture.app.reload()
        fixture.app.select(activity: .surfing)
        fixture.intentStorage.save(activity: .surfing)
        await fixture.app.applyIntentSelectionIfNeeded()

        XCTAssertEqual(fixture.app.activity, .surfing)
        XCTAssertNil(fixture.defaults.string(forKey: IntentSelectionStorage.activityKey))
    }

    func testAnUnknownActivityKeyIsDroppedInsteadOfResettingTheChoice() async throws {
        let fixture = try makeApp()

        await fixture.app.reload()
        fixture.app.select(activity: .walking)

        // A stale identifier from an older build: never mapped to a default
        // activity, only cleared (invariant 3: no invented value).
        fixture.defaults.set("yoga", forKey: IntentSelectionStorage.activityKey)
        await fixture.app.applyIntentSelectionIfNeeded()

        XCTAssertEqual(fixture.app.activity, .walking)
        XCTAssertNil(fixture.defaults.string(forKey: IntentSelectionStorage.activityKey))
    }

    // MARK: - Both at once

    func testASpotAndAnActivityHitApplyTogether() async throws {
        let fixture = try makeApp()

        await fixture.app.reload()
        fixture.spotStorage.save(SpotCatalog.arcachonEyrac.id)
        fixture.intentStorage.save(activity: .boating)
        await fixture.app.applyIntentSelectionIfNeeded()

        XCTAssertEqual(fixture.app.selectedSpot.id, SpotCatalog.arcachonEyrac.id)
        XCTAssertEqual(fixture.app.activity, .boating)
        let decision = try XCTUnwrap(fixture.app.decision)
        XCTAssertEqual(decision.spot.id, SpotCatalog.arcachonEyrac.id)
        XCTAssertEqual(decision.activity, .boating)
    }

    // MARK: - Fixtures

    private struct Fixture {
        let app: AppModel
        let provider: StubConditionsProvider
        let defaults: UserDefaults
        let spotStorage: SpotSelectionStorage
        let intentStorage: IntentSelectionStorage
    }

    private func makeApp() throws -> Fixture {
        let suite = "EstranTests.OpenIntent.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suite)
        }
        let provider = StubConditionsProvider()
        let spotStorage = SpotSelectionStorage(defaults: defaults)
        let intentStorage = IntentSelectionStorage(defaults: defaults)
        let app = AppModel(
            provider: provider,
            selectionStorage: spotStorage,
            intentSelection: intentStorage,
            activityStorage: ActivitySelectionStorage(defaults: defaults),
            // No model in tests: the template sentence is the display floor.
            reasonProvider: TemplateReasonProvider())
        return Fixture(
            app: app,
            provider: provider,
            defaults: defaults,
            spotStorage: spotStorage,
            intentStorage: intentStorage)
    }
}

/// Thread-safe call count, so a test can prove a refresh did *not* happen.
private final class LoadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

/// Real `Conditions` values, no network and no tide dataset: fixed weather on
/// a plausible tide, so every activity has an answer.
private struct StubConditionsProvider: ConditionsProviding {
    let isSampleData = true
    let counter = LoadCounter()

    func conditions(for spot: Spot, at date: Date) async throws -> Conditions {
        counter.increment()
        return Self.conditions(for: spot, at: date)
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
