@testable import Estran
import EstranCore
import Foundation
import XCTest

/// W-LACAUTION — the caution the Live Activity carries: the app's own composed
/// sentence (night, light rain, the Bassin passes), passed through the state,
/// never reworded, never doubled for swimming, and still readable by a build
/// that predates the field.
@MainActor
final class LiveActivityCautionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_793_000_000)

    private static let hour: TimeInterval = 60 * 60

    // MARK: - Controller

    func testTheControllerCarriesTheSnapshotsComposedCaution() {
        let state = LiveActivityController.contentState(
            snapshot: snapshot(
                activity: .shoreFishing,
                lines: [line(.shoreFishing, warning: ActivityCaution.nightFishing)]),
            current: nil,
            upcoming: slot(start: Self.hour, end: 3 * Self.hour),
            now: now)

        XCTAssertEqual(
            state.caution,
            ActivityCaution.nightFishing,
            "the Live Activity shows the app's own sentence, never a new one")
        XCTAssertTrue(state.isGo, "night is a caution, not a blocker")
    }

    func testTheControllerCarriesTheLongBassinPassesCaution() {
        let composed = ActivityCaution.boatingPasses + " " + ActivityCaution.nightBoating
        let state = LiveActivityController.contentState(
            snapshot: snapshot(
                activity: .boating,
                lines: [line(.boating, warning: composed)]),
            current: nil,
            upcoming: slot(start: Self.hour, end: 3 * Self.hour, activity: .boating),
            now: now)

        XCTAssertEqual(state.caution, composed)
    }

    func testSwimmingKeepsNoSeparateCaution() {
        let advisory = SwimmingAdvisory(level: .moderate, region: .bassin)
        let state = LiveActivityController.contentState(
            snapshot: snapshot(
                activity: .swimming,
                isGo: false,
                advisory: advisory,
                lines: [line(.swimming, isGo: false, warning: "Baïnes et courants dangereux.")]),
            current: nil,
            upcoming: nil,
            now: now)

        XCTAssertNil(
            state.caution,
            "the advisory already carries the warning: it is never doubled")
        XCTAssertEqual(state.swimmingAdvisory, advisory)
    }

    func testASnapshotWithoutACautionGivesAStateWithoutCaution() {
        let state = LiveActivityController.contentState(
            snapshot: snapshot(activity: .shoreFishing, lines: [line(.shoreFishing)]),
            current: nil,
            upcoming: slot(start: Self.hour, end: 3 * Self.hour),
            now: now)

        XCTAssertNil(state.caution, "no caution in the snapshot, none invented")
    }

    // MARK: - Codable

    func testAContentStateRoundTripsItsCaution() throws {
        let state = GoActivityAttributes.ContentState(
            isGo: true,
            activityName: "Bateau",
            nextWindowStart: now.addingTimeInterval(Self.hour),
            updatedAt: now,
            caution: ActivityCaution.boatingPasses)

        let decoded = try Self.roundTrip(state)

        XCTAssertEqual(decoded, state)
        XCTAssertEqual(decoded.caution, ActivityCaution.boatingPasses)
    }

    func testAContentStateWithoutACautionRoundTrips() throws {
        let state = GoActivityAttributes.ContentState(
            isGo: false,
            activityName: "Surf",
            nextWindowStart: nil,
            updatedAt: now)

        let decoded = try Self.roundTrip(state)

        XCTAssertEqual(decoded, state)
        XCTAssertNil(decoded.caution)
    }

    func testAStateWrittenBeforeTheCautionStillDecodes() throws {
        let state = GoActivityAttributes.ContentState(
            isGo: true,
            activityName: "Bateau",
            nextWindowStart: nil,
            updatedAt: now,
            caution: ActivityCaution.boatingPasses)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(state)) as? [String: Any])
        object.removeValue(forKey: "caution")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let decoded = try decoder.decode(
            GoActivityAttributes.ContentState.self,
            from: JSONSerialization.data(withJSONObject: object))

        XCTAssertNil(decoded.caution, "an absent caution is no caution, never invented copy")
        XCTAssertTrue(decoded.isGo)
    }

    private static func roundTrip(
        _ state: GoActivityAttributes.ContentState) throws -> GoActivityAttributes.ContentState
    {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(
            GoActivityAttributes.ContentState.self,
            from: encoder.encode(state))
    }

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
        advisory: SwimmingAdvisory? = nil,
        lines: [WidgetSnapshot.ActivityLine] = []) -> WidgetSnapshot
    {
        WidgetSnapshot(
            updatedAt: now,
            spotID: "arcachon-eyrac",
            spotName: "Arcachon-Eyrac",
            activity: activity,
            isGo: isGo,
            isUnavailable: false,
            answer: isGo ? "13 h 10 à 15 h 40" : "Coefficient trop faible",
            swimmingAdvisory: advisory,
            lines: lines)
    }

    private func line(
        _ activity: Activity,
        isGo: Bool = true,
        warning: String? = nil) -> WidgetSnapshot.ActivityLine
    {
        WidgetSnapshot.ActivityLine(
            activity: activity,
            isUnavailable: false,
            isGo: isGo,
            answer: isGo ? "13 h 10 à 15 h 40" : "Coefficient trop faible",
            warning: warning)
    }
}
