@testable import EstranCore
import XCTest

/// Interval-based fail-closed gate (review Z13).
///
/// The nominal sample can pass while the uncertainty interval contains a low
/// water below the draught, a low water too far from the decision time, or a
/// strong-current phase band. The verdict must then be `Non` with
/// « Marge insuffisante », never `Oui`.
final class UncertaintyGateTests: XCTestCase {
    private let engine = DecisionEngine()

    private func boatingSpot(uncertainty: TideUncertainty) -> Spot {
        Spot(
            id: "boating-test",
            name: "Boating test",
            region: .bassin,
            coordinate: Coordinate(latitude: 44.66, longitude: -1.17),
            tideStation: TideStationRef(id: "190", name: "ARCACHON_EYRAC"),
            supportedActivities: Set(Activity.allCases),
            timezone: DecisionFixtures.timezone,
            coastOrientationDegrees: 270,
            minimumWaterHeight: 0.5,
            validation: .gauged,
            correctionStatus: .calibrated,
            uncertainty: uncertainty)
    }

    // MARK: - Boating: a low water inside the interval

    func testBoatingLowWaterInsideTheEnvelopeBlocksTheVerdict() {
        let date = DecisionFixtures.date("2025-06-01T12:00:00Z")
        // Low water 30 min before the decision, high water 5.5 h after.
        // Nominal height at `date` is 0.2 + 4.0 × (30/360) = 0.533 m, above
        // the 0.5 m draught; the interval [-60, +60] min contains the 0.2 m low.
        let tide = DecisionFixtures.tide(
            at: date,
            coefficient: 95,
            currentKind: .low,
            currentHeight: 0.2,
            nextKind: .high,
            nextHeight: 4.2,
            minutesSinceCurrent: 30,
            minutesToNext: 330)
        let spot = boatingSpot(
            uncertainty: TideUncertainty(timeMinutes: 60, heightMeters: 0.1))
        let conditions = DecisionFixtures.conditions(
            at: date,
            tide: tide,
            weather: DecisionFixtures.weather(windSpeed: 10),
            swell: DecisionFixtures.swell(waveHeight: 0.6),
            spot: spot)

        // The nominal sample alone would pass the water gate.
        XCTAssertEqual(tide.height(at: date) ?? 0, 0.533, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(tide.height(at: date) ?? 0, 0.5)

        let decision = engine.decide(activity: .boating, conditions: conditions)
        XCTAssertFalse(decision.go)
        XCTAssertEqual(decision.reason, "Marge insuffisante.")
    }

    func testBoatingWithoutEnvelopeKeepsTheNominalVerdict() {
        let date = DecisionFixtures.date("2025-06-01T12:00:00Z")
        let tide = DecisionFixtures.tide(
            at: date,
            coefficient: 95,
            currentKind: .low,
            currentHeight: 0.2,
            nextKind: .high,
            nextHeight: 4.2,
            minutesSinceCurrent: 30,
            minutesToNext: 330)
        let conditions = DecisionFixtures.conditions(
            at: date,
            tide: tide,
            weather: DecisionFixtures.weather(windSpeed: 10),
            swell: DecisionFixtures.swell(waveHeight: 0.6),
            spot: boatingSpot(uncertainty: .none))

        let decision = engine.decide(activity: .boating, conditions: conditions)
        XCTAssertTrue(decision.go)
    }

    // MARK: - Shore fishing: a low water at the edge of the interval

    func testShoreFishingEnvelopePushesTheLowWaterOutOfRange() {
        let date = DecisionFixtures.date("2025-06-01T12:00:00Z")
        // Low water 100 min before the decision: nominal is inside the ±2 h
        // gate, but the +60 min edge is 160 min away.
        let tide = DecisionFixtures.tide(
            at: date,
            coefficient: 95,
            currentKind: .low,
            currentHeight: 0.4,
            nextKind: .high,
            nextHeight: 4.4,
            minutesSinceCurrent: 100,
            minutesToNext: 260)
        // Range 4.0 m is inside the shipped 190 grey band (3.58..4.18):
        // moderate, never « faibles ».
        let spot = SpotCatalog.arcachonEyrac
            .withUncertainty(TideUncertainty(timeMinutes: 60, heightMeters: 0))
        let conditions = DecisionFixtures.conditions(
            at: date,
            tide: tide,
            weather: DecisionFixtures.weather(windSpeed: 10),
            spot: spot)

        XCTAssertEqual(tide.minutesFromNearestEvent(of: .low, to: date) ?? 0, 100, accuracy: 0.001)
        let decision = engine.decide(activity: .shoreFishing, conditions: conditions)
        XCTAssertFalse(decision.go)
        XCTAssertEqual(decision.reason, "Marge insuffisante.")
    }

    // MARK: - Swimming: the phase band is crossed between the endpoints

    func testSwimmingRangeInsideTheGreyBandBlocks() {
        let date = DecisionFixtures.date("2025-06-01T12:00:00Z")
        // Low water 3 h before, high water 5.5 h after: phase 0.353 at `date`,
        // 0.471 at +60 min. The nominal phase is outside 0.4...0.6, the
        // interval crosses it.
        let tide = DecisionFixtures.tide(
            at: date,
            coefficient: 110,
            currentKind: .low,
            currentHeight: 0.4,
            nextKind: .high,
            nextHeight: 4.4,
            minutesSinceCurrent: 180,
            minutesToNext: 330)
        // Range 4.0 m is inside the shipped 190 grey band (3.58..4.18):
        // moderate, never « faibles ».
        let spot = SpotCatalog.arcachonEyrac
            .withUncertainty(TideUncertainty(timeMinutes: 60, heightMeters: 0))
        let conditions = DecisionFixtures.conditions(
            at: date,
            tide: tide,
            weather: DecisionFixtures.weather(temperature: 25, windSpeed: 10),
            swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: 20),
            spot: spot)

        XCTAssertEqual(tide.progress(at: date) ?? 0, 0.353, accuracy: 0.002)
        XCTAssertFalse(SwimmingRule.strongCurrentBand.contains(tide.progress(at: date) ?? 0))

        let decision = engine.decide(activity: .swimming, conditions: conditions)
        XCTAssertFalse(decision.go)
        XCTAssertEqual(decision.reason, "Marge insuffisante.")
    }

    func testSwimmingLowRangeIsAGoWithoutEnvelope() {
        let date = DecisionFixtures.date("2025-06-01T12:00:00Z")
        let tide = DecisionFixtures.tide(
            at: date,
            coefficient: 110,
            currentKind: .low,
            currentHeight: 0.4,
            nextKind: .high,
            nextHeight: 4.4,
            minutesSinceCurrent: 180,
            minutesToNext: 330)
        let conditions = DecisionFixtures.conditions(
            at: date,
            tide: tide,
            weather: DecisionFixtures.weather(temperature: 25, windSpeed: 10),
            swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: 20))

        let decision = engine.decide(activity: .swimming, conditions: conditions)
        XCTAssertTrue(decision.go)
    }

    // MARK: - Interval helpers

    func testMinimumHeightUsesTheExactEventBetweenCurveSamples() {
        let date = DecisionFixtures.date("2025-06-01T12:00:00Z")
        let tide = DecisionFixtures.tide(
            at: date,
            currentKind: .low,
            currentHeight: 0.2,
            nextKind: .high,
            nextHeight: 4.2,
            minutesSinceCurrent: 30,
            minutesToNext: 330)
        let start = date.addingTimeInterval(-60 * 60)
        let end = date.addingTimeInterval(60 * 60)
        XCTAssertEqual(tide.minimumHeight(from: start, to: end) ?? 0, 0.2, accuracy: 1e-9)
    }

    func testPhaseIntersectionDetectsAnExtremumInsideTheInterval() {
        let date = DecisionFixtures.date("2025-06-01T12:00:00Z")
        let tide = DecisionFixtures.tide(
            at: date,
            currentKind: .low,
            currentHeight: 0.4,
            nextKind: .high,
            nextHeight: 4.4,
            minutesSinceCurrent: 30,
            minutesToNext: 330)
        // The low water at -30 min is inside the interval: the phase wraps.
        XCTAssertEqual(
            tide.phaseIntersects(
                0.4 ... 0.6,
                from: date.addingTimeInterval(-60 * 60),
                to: date.addingTimeInterval(60 * 60)),
            true)
    }
}
