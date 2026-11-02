@testable import Estran
import EstranCore
import Foundation
import XCTest

/// The Live Activity rules and the state it renders: when the card exists, what
/// it says, and the swimming rule that no surface may break.
///
/// Main-actor isolated because `LiveActivityController` is: the builder stays on
/// the type that owns it, and the tests reach it the way the app does.
@MainActor
final class LiveActivityTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_793_000_000)

    private static let minute: TimeInterval = 60
    private static let hour: TimeInterval = 60 * 60

    // MARK: - Fixtures

    private func slot(
        start: TimeInterval,
        end: TimeInterval,
        activity: Activity = .shoreFishing) -> ActivitySlot
    {
        ActivitySlot(
            activity: activity,
            window: DateInterval(
                start: now.addingTimeInterval(start),
                end: now.addingTimeInterval(end)),
            score: 0.8,
            go: true)
    }

    private func snapshot(
        activity: Activity = .shoreFishing,
        isGo: Bool = true,
        isUnavailable: Bool = false,
        advisory: SwimmingAdvisory? = nil) -> WidgetSnapshot
    {
        WidgetSnapshot(
            updatedAt: now,
            spotID: "arcachon-eyrac",
            spotName: "Arcachon-Eyrac",
            activity: activity,
            isGo: isGo,
            isUnavailable: isUnavailable,
            answer: isGo ? "13 h 10 à 15 h 40" : "Coefficient trop faible",
            swimmingAdvisory: advisory)
    }

    // MARK: - Policy

    func testARunningWindowRunsTheActivity() {
        let current = slot(start: -Self.hour, end: Self.hour)

        XCTAssertTrue(LiveActivityPolicy.shouldRun(now: now, current: current, upcoming: nil))
        XCTAssertFalse(
            LiveActivityPolicy.shouldEnd(now: now, current: current),
            "a refresh inside the window must never dismiss the card")
    }

    func testAWindowInOneHourRunsTheActivity() {
        let upcoming = slot(start: Self.hour, end: 3 * Self.hour)

        XCTAssertTrue(LiveActivityPolicy.shouldRun(now: now, current: nil, upcoming: upcoming))
        XCTAssertTrue(LiveActivityPolicy.shouldEnd(now: now, current: nil))
    }

    func testAWindowInSixHoursDoesNotRunTheActivity() {
        let upcoming = slot(start: 6 * Self.hour, end: 8 * Self.hour)

        XCTAssertFalse(LiveActivityPolicy.shouldRun(now: now, current: nil, upcoming: upcoming))
        XCTAssertTrue(LiveActivityPolicy.shouldEnd(now: now, current: nil))
    }

    func testAWindowExactlyTwoHoursAwayRunsTheActivity() {
        let upcoming = slot(start: 2 * Self.hour, end: 3 * Self.hour)

        XCTAssertTrue(
            LiveActivityPolicy.shouldRun(now: now, current: nil, upcoming: upcoming),
            "the lookahead boundary is inclusive: two hours is still worth a card")
    }

    func testAWindowPastTheLookaheadDoesNotRunTheActivity() {
        let upcoming = slot(start: 2 * Self.hour + 1, end: 3 * Self.hour)

        XCTAssertFalse(
            LiveActivityPolicy.shouldRun(now: now, current: nil, upcoming: upcoming),
            "one second past two hours is not « dans les deux heures »")
    }

    func testAWindowEndedTwentyMinutesAgoEndsTheActivity() {
        let past = slot(start: -2 * Self.hour, end: -20 * Self.minute)

        XCTAssertFalse(LiveActivityPolicy.shouldRun(now: now, current: past, upcoming: nil))
        XCTAssertTrue(LiveActivityPolicy.shouldEnd(now: now, current: past))
    }

    func testAWindowEndedWithinTheGracePeriodStaysUp() {
        let justEnded = slot(start: -2 * Self.hour, end: -5 * Self.minute)

        XCTAssertFalse(
            LiveActivityPolicy.shouldEnd(now: now, current: justEnded),
            "15 min of grace: the card does not vanish the second the window closes")
    }

    func testNoWindowsMeansNoActivity() {
        XCTAssertFalse(LiveActivityPolicy.shouldRun(now: now, current: nil, upcoming: nil))
        XCTAssertTrue(LiveActivityPolicy.shouldEnd(now: now, current: nil))
        XCTAssertNil(LiveActivityPolicy.nextWindowStart(now: now, current: nil, upcoming: nil))
    }

    // MARK: - Next window

    func testTheNextWindowStartIsTheUpcomingWindow() {
        let upcoming = slot(start: Self.hour, end: 3 * Self.hour)

        XCTAssertEqual(
            LiveActivityPolicy.nextWindowStart(now: now, current: nil, upcoming: upcoming),
            upcoming.window.start)
    }

    func testTheNextWindowStartIgnoresARunningWindow() {
        let current = slot(start: -Self.hour, end: Self.hour)
        let upcoming = slot(start: 3 * Self.hour, end: 4 * Self.hour)

        XCTAssertEqual(
            LiveActivityPolicy.nextWindowStart(now: now, current: current, upcoming: upcoming),
            upcoming.window.start)
        XCTAssertNil(
            LiveActivityPolicy.nextWindowStart(now: now, current: current, upcoming: current),
            "a window that contains now is the current one, never « le prochain »")
    }

    // MARK: - State

    func testSwimmingCarriesARiskLevelNeverAVerdict() {
        let advisory = SwimmingAdvisory(level: .moderate, region: .bassin)
        let state = LiveActivityController.contentState(
            snapshot: snapshot(activity: .swimming, isGo: false, advisory: advisory),
            current: nil,
            upcoming: nil,
            now: now)

        XCTAssertFalse(state.isGo, "swimming is a risk level on the Live Activity too")
        XCTAssertFalse(state.isUnavailable, "swimming says its level, never « Données indisponibles »")
        XCTAssertTrue(state.isSwimming)
        XCTAssertEqual(state.activityName, "Baignade")
        XCTAssertEqual(state.swimmingAdvisory, advisory)
        XCTAssertEqual(state.updatedAt, now)
    }

    func testASwimmingSnapshotClaimingGoStillDoesNotBecomeAGo() {
        let state = LiveActivityController.contentState(
            snapshot: snapshot(activity: .swimming, isGo: true),
            current: nil,
            upcoming: nil,
            now: now)

        XCTAssertFalse(state.isGo, "the surface refuses a Oui even from a bad snapshot")
        XCTAssertTrue(state.isSwimming)
    }

    func testAStandardActivityCarriesTheVerdictAndNoAdvisory() {
        let upcoming = slot(start: Self.hour, end: 3 * Self.hour)
        let state = LiveActivityController.contentState(
            snapshot: snapshot(activity: .shoreFishing),
            current: nil,
            upcoming: upcoming,
            now: now)

        XCTAssertTrue(state.isGo)
        XCTAssertFalse(state.isSwimming)
        XCTAssertEqual(state.activityName, "Pêche à pied")
        XCTAssertNil(state.swimmingAdvisory)
        XCTAssertEqual(state.nextWindowStart, upcoming.window.start)
    }

    func testAnUnavailableVerdictSaysSoAndIsNotAGo() {
        let state = LiveActivityController.contentState(
            snapshot: snapshot(activity: .surfing, isGo: false, isUnavailable: true),
            current: nil,
            upcoming: nil,
            now: now)

        XCTAssertFalse(state.isGo)
        XCTAssertTrue(
            state.isUnavailable,
            "missing data renders « Données indisponibles », never « Non »")
        XCTAssertFalse(state.isSwimming)
        XCTAssertNil(state.swimmingAdvisory)
    }

    func testASwimmingSnapshotWithUnavailableDataStillCarriesItsLevel() {
        let advisory = SwimmingAdvisory(level: .unknown, region: .bassin)
        let state = LiveActivityController.contentState(
            snapshot: snapshot(
                activity: .swimming,
                isGo: false,
                isUnavailable: true,
                advisory: advisory),
            current: nil,
            upcoming: nil,
            now: now)

        XCTAssertFalse(state.isGo)
        XCTAssertFalse(
            state.isUnavailable,
            "swimming keeps its level and advisory instead of a verdict")
        XCTAssertTrue(state.isSwimming)
        XCTAssertEqual(state.swimmingAdvisory, advisory)
    }

    func testAStateWrittenBeforeTheUnavailableFlagStillDecodes() throws {
        let state = GoActivityAttributes.ContentState(
            isGo: true,
            activityName: "Pêche à pied",
            nextWindowStart: nil,
            updatedAt: now)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(state)) as? [String: Any])
        object.removeValue(forKey: "isUnavailable")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let decoded = try decoder.decode(
            GoActivityAttributes.ContentState.self,
            from: JSONSerialization.data(withJSONObject: object))

        XCTAssertFalse(decoded.isUnavailable, "an absent flag is a readable verdict")
        XCTAssertTrue(decoded.isGo)
    }
}
