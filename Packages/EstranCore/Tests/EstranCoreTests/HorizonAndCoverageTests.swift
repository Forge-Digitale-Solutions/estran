@testable import EstranCore
import XCTest

/// Interval coverage and validity horizon (review Z15, Z16, Z18).
///
/// The safety gate reads the tide over `[t − u_t, t + u_t]`. Two failure modes
/// must be impossible: reading a partial interval because the day curve stops at
/// midnight, and predicting past `validUntil` because only `t` is checked.
final class HorizonAndCoverageTests: XCTestCase {
    private let engineDate = TideFixtures.date("2025-06-01T12:00:00Z")

    private func station(validUntil: Date? = nil) -> TidalStation {
        TidalStation(
            id: "synthetic-m2",
            name: "Synthetic M2 Station",
            coordinate: Coordinate(latitude: 0, longitude: 0),
            timezoneIdentifier: "UTC",
            meanSeaLevel: 2.0,
            meanSpringRange: 5.0,
            constituents: [HarmonicConstituent(symbol: "M2", amplitude: 2.5, phaseDegrees: 0)],
            attribution: "Synthetic test fixture",
            validUntil: validUntil)
    }

    private func boatingSpot(uncertainty: TideUncertainty) -> Spot {
        Spot(
            id: "coverage-test",
            name: "Coverage test",
            region: .bassin,
            coordinate: Coordinate(latitude: 44.66, longitude: -1.17),
            tideStation: TideStationRef(id: "synthetic-m2", name: "Synthetic M2 Station"),
            supportedActivities: Set(Activity.allCases),
            timezone: DecisionFixtures.timezone,
            coastOrientationDegrees: 270,
            minimumWaterHeight: 1.0,
            validation: .gauged,
            correctionStatus: .none,
            uncertainty: uncertainty)
    }

    // MARK: - Z15: the interval must be covered across local midnight

    func testEngineStateCoversTheEnvelopeAroundMidnight() async throws {
        let engine = try TideEngine(stations: [station()])
        let envelope = TideUncertainty(timeMinutes: 45, heightMeters: 0.55)

        for iso in ["2025-06-01T23:55:00Z", "2025-06-02T00:05:00Z"] {
            let at = TideFixtures.date(iso)
            let state = try await engine.state(for: "synthetic-m2", at: at)
            XCTAssertTrue(
                state.coversInterval(
                    from: at.addingTimeInterval(-envelope.timeInterval),
                    to: at.addingTimeInterval(envelope.timeInterval)),
                "the safety curve must cover ±\(envelope.timeMinutes) min around \(iso)")
            XCTAssertNotNil(
                state.minimumHeight(
                    from: at.addingTimeInterval(-envelope.timeInterval),
                    to: at.addingTimeInterval(envelope.timeInterval)))
        }
    }

    func testIntervalOutsideTheSafetyCurveIsRejected() {
        let at = engineDate
        let state = TideState(
            current: TideEvent(time: at.addingTimeInterval(-1800), kind: .low, height: 0.4),
            next: TideEvent(time: at.addingTimeInterval(1800), kind: .high, height: 4.4),
            coefficient: 95,
            coefficientSource: .nationalBrest,
            curve: [
                TidePoint(time: at.addingTimeInterval(-1800), height: 0.4),
                TidePoint(time: at, height: 2.4),
                TidePoint(time: at.addingTimeInterval(1800), height: 4.4)
            ])

        // The state only covers ±30 min; the gate would read ±180 min.
        XCTAssertNil(state.minimumHeight(
            from: at.addingTimeInterval(-180 * 60),
            to: at.addingTimeInterval(180 * 60)))

        let conditions = DecisionFixtures.conditions(
            at: at,
            tide: state,
            weather: DecisionFixtures.weather(windSpeed: 10),
            swell: DecisionFixtures.swell(waveHeight: 0.6),
            spot: boatingSpot(uncertainty: TideUncertainty(timeMinutes: 180, heightMeters: 0.55)))

        let decision = DecisionEngine().decide(activity: .boating, conditions: conditions)
        XCTAssertFalse(decision.go)
        XCTAssertEqual(decision.reason, "Données indisponibles.")
    }

    // MARK: - Z16: the horizon is checked at t + u_t, not at t

    func testHorizonIsCheckedAtTheEndOfTheUncertaintyInterval() async throws {
        let validUntil = TideFixtures.date("2027-12-31T23:59:59Z")
        let engine = try TideEngine(stations: [station(validUntil: validUntil)])
        let spot = boatingSpot(uncertainty: TideUncertainty(timeMinutes: 45, heightMeters: 0.55))

        // 10 min before the horizon: `t` is valid, but `t + 45 min` is not.
        let nearHorizon = validUntil.addingTimeInterval(-10 * 60)
        let nearState = try await engine.state(for: "synthetic-m2", at: nearHorizon)
        let nearConditions = DecisionFixtures.conditions(
            at: nearHorizon,
            tide: nearState,
            weather: DecisionFixtures.weather(windSpeed: 10),
            swell: DecisionFixtures.swell(waveHeight: 0.6),
            spot: spot)
        XCTAssertTrue(
            DecisionEngine().rule(for: .boating)?.blockers(nearConditions).contains(.dataUnavailable) ?? false)

        // Two hours before the horizon the whole interval is inside it.
        let safeDate = validUntil.addingTimeInterval(-120 * 60)
        let safeState = try await engine.state(for: "synthetic-m2", at: safeDate)
        XCTAssertEqual(safeState.validUntil, validUntil)
        let safeConditions = DecisionFixtures.conditions(
            at: safeDate,
            tide: safeState,
            weather: DecisionFixtures.weather(windSpeed: 10),
            swell: DecisionFixtures.swell(waveHeight: 0.6),
            spot: spot)
        XCTAssertFalse(
            DecisionEngine().rule(for: .boating)?.blockers(safeConditions).contains(.dataUnavailable) ?? true)
    }

    func testEngineMarksTheCoefficientAsALocalProxy() async throws {
        let engine = try TideEngine(stations: [station()])
        let state = try await engine.state(for: "synthetic-m2", at: engineDate)
        XCTAssertEqual(state.coefficientSource, .localProxy)
    }

    // MARK: - Z18/Z11: the swimming level needs a calibrated range

    func testSwimmingFailsClosedWithoutACalibratedRange() async throws {
        let engine = try TideEngine(stations: [station()])
        let at = TideFixtures.date("2025-06-21T12:00:00Z")
        let state = try await engine.state(for: "synthetic-m2", at: at)

        let spot = Spot(
            id: "swim-test",
            name: "Swim test",
            region: .bassin,
            coordinate: Coordinate(latitude: 44.66, longitude: -1.17),
            tideStation: TideStationRef(id: "synthetic-m2", name: "Synthetic M2 Station"),
            supportedActivities: Set(Activity.allCases),
            timezone: DecisionFixtures.timezone,
            validation: .gauged,
            correctionStatus: .none,
            uncertainty: TideUncertainty(timeMinutes: 45, heightMeters: 0.55))
        let conditions = DecisionFixtures.conditions(
            at: at,
            tide: state,
            weather: DecisionFixtures.weather(temperature: 24, windSpeed: 10),
            swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: 20),
            spot: spot)

        let decision = DecisionEngine().decide(activity: .swimming, conditions: conditions)
        XCTAssertFalse(decision.go)
        XCTAssertTrue(decision.isDataUnavailable)
        XCTAssertTrue(decision.blockers.contains(.currentDataUnavailable))
    }
}
