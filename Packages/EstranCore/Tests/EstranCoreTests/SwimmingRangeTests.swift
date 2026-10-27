@testable import EstranCore
import XCTest

/// The swimming current level is a pure function of the local predicted range
/// and the tide phase. The grey band `T ± 0.30 m` may never be shown as `low`.
final class SwimmingRangeTests: XCTestCase {
    private let at = DecisionFixtures.date("2026-06-21T12:00:00Z")
    private let range = SwimmingRange(lowBelow: 3.58, strongAt: 4.18)

    private func conditions(
        range meters: Double,
        phase: Double,
        swimmingRange: SwimmingRange? = nil) -> Conditions
    {
        let total = 3600.0
        let current = TideEvent(
            time: at.addingTimeInterval(-phase * total),
            kind: .low,
            height: 0)
        let next = TideEvent(
            time: at.addingTimeInterval((1 - phase) * total),
            kind: .high,
            height: meters)
        let state = TideState(
            current: current,
            next: next,
            coefficient: 80,
            coefficientSource: .nationalBrest,
            coefficientValidated: true,
            curve: [
                TidePoint(time: at.addingTimeInterval(-total), height: 0),
                TidePoint(time: at, height: meters),
                TidePoint(time: at.addingTimeInterval(total), height: 0)
            ])
        let spot = Spot(
            id: "swim-test",
            name: "Swim test",
            region: .bassin,
            coordinate: Coordinate(latitude: 44.66, longitude: -1.17),
            tideStation: TideStationRef(id: "190", name: "ARCACHON_EYRAC"),
            supportedActivities: Set(Activity.allCases),
            timezone: DecisionFixtures.timezone,
            validation: .gauged,
            correctionStatus: .none,
            uncertainty: TideUncertainty(timeMinutes: 45, heightMeters: 0.55),
            swimmingRange: swimmingRange ?? range)
        return DecisionFixtures.conditions(
            at: at,
            tide: state,
            weather: DecisionFixtures.weather(temperature: 24, windSpeed: 10),
            swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: 20),
            spot: spot)
    }

    func testTopFivePercentRangeAtMidTideIsNeverLow() throws {
        let rule = try XCTUnwrap(DecisionEngine().rule(for: .swimming))
        let blockers = rule.blockers(conditions(range: 4.5, phase: 0.5))
        XCTAssertTrue(blockers.contains(.strongCurrent))
        XCTAssertFalse(blockers.contains(.dataUnavailable))
    }

    func testRangeInsideTheGreyBandIsNeverLow() throws {
        let rule = try XCTUnwrap(DecisionEngine().rule(for: .swimming))
        // 3.8 m is between lowBelow 3.58 and strongAt 4.18, at slack water.
        let blockers = rule.blockers(conditions(range: 3.8, phase: 0.0))
        XCTAssertTrue(blockers.contains(.insufficientMargin))
        XCTAssertFalse(blockers.contains(.strongCurrent))
    }

    func testSlackOnAVeryLargeRangeIsNotStrong() throws {
        let rule = try XCTUnwrap(DecisionEngine().rule(for: .swimming))
        let blockers = rule.blockers(conditions(range: 4.8, phase: 0.0))
        XCTAssertFalse(blockers.contains(.strongCurrent))
        XCTAssertTrue(blockers.contains(.insufficientMargin))
    }

    func testLowRangeStaysLowEvenAtMidTide() throws {
        let rule = try XCTUnwrap(DecisionEngine().rule(for: .swimming))
        let blockers = rule.blockers(conditions(range: 3.0, phase: 0.5))
        XCTAssertFalse(blockers.contains(.strongCurrent))
        XCTAssertFalse(blockers.contains(.insufficientMargin))
    }

    func testTheLevelNeverContainsOuiOrNon() {
        let decision = DecisionEngine().decide(
            activity: .swimming,
            conditions: conditions(range: 4.5, phase: 0.5))
        let level = SwimmingRiskLevel(decision: decision)
        XCTAssertEqual(level, .strong)
        XCTAssertFalse(level.title.contains("Oui"))
        XCTAssertFalse(level.title.contains("Non"))
    }

    func testInvalidRangeIsRejected() {
        XCTAssertFalse(SwimmingRange(lowBelow: 4.2, strongAt: 4.2).isValid)
        XCTAssertFalse(SwimmingRange(lowBelow: 0, strongAt: 4.2).isValid)
        XCTAssertTrue(range.isValid)
    }
}
