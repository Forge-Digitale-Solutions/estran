@testable import EstranCore
import XCTest

/// Boundary and missing-data checks for the §7.1 hard gates (review B2–B4).
///
/// Each case pins the gate value itself, so an off-by-one or a neutral fallback
/// fails the test instead of silently turning a failed gate into `Oui`.
final class SafetyGatesTests: XCTestCase {
    private let noon = DecisionFixtures.date("2026-06-21T10:00:00Z")
    private let summerNoon = DecisionFixtures.date("2026-06-21T12:00:00Z")

    private func rule(_ activity: Activity) throws -> any ActivityRule {
        try XCTUnwrap(DecisionEngine().rule(for: activity))
    }

    private func conditions(
        at date: Date,
        tide: TideState? = nil,
        weather: WeatherNow? = nil,
        swell: Swell? = nil,
        spot: Spot? = nil) -> Conditions
    {
        DecisionFixtures.conditions(
            at: date,
            tide: tide ?? DecisionFixtures.tide(at: date),
            weather: weather ?? DecisionFixtures.weather(),
            swell: swell ?? DecisionFixtures.swell(),
            spot: spot ?? DecisionFixtures.arcachon)
    }

    // MARK: Pêche à pied

    func testShoreFishingGates() throws {
        let rule = try rule(.shoreFishing)

        let atGate = conditions(
            at: noon,
            tide: DecisionFixtures.tide(at: noon, coefficient: 72, minutesSinceCurrent: 40),
            weather: DecisionFixtures.weather(windSpeed: 14.9))
        XCTAssertFalse(rule.blockers(atGate).contains(.coefficient))
        XCTAssertFalse(rule.blockers(atGate).contains(.wind))
        XCTAssertFalse(rule.blockers(atGate).contains(.tideTiming))

        let belowCoefficient = conditions(
            at: noon,
            tide: DecisionFixtures.tide(at: noon, coefficient: 71, minutesSinceCurrent: 40))
        XCTAssertTrue(rule.blockers(belowCoefficient).contains(.coefficient))

        let tooWindy = conditions(at: noon, weather: DecisionFixtures.weather(windSpeed: 15))
        XCTAssertTrue(rule.blockers(tooWindy).contains(.wind))

        let tooFar = conditions(
            at: noon,
            tide: DecisionFixtures.tide(
                at: noon,
                coefficient: 90,
                currentKind: .low,
                nextKind: .high,
                minutesSinceCurrent: 121,
                minutesToNext: 200))
        XCTAssertTrue(rule.blockers(tooFar).contains(.tideTiming))

        let noLowWater = conditions(
            at: noon,
            tide: TideState(
                current: TideEvent(time: noon, kind: .high, height: 4),
                next: nil,
                coefficient: 90,
                curve: []))
        XCTAssertTrue(rule.blockers(noLowWater).contains(.dataUnavailable))
    }

    // MARK: Surf

    func testSurfGates() throws {
        let rule = try rule(.surfing)

        let atGate = conditions(
            at: noon,
            weather: DecisionFixtures.weather(windSpeed: 19.9, windDirection: 90),
            swell: DecisionFixtures.swell(waveHeight: 2.5, period: 14, directionDegrees: 270))
        XCTAssertEqual(rule.blockers(atGate), [])

        let tooSmall = conditions(at: noon, swell: DecisionFixtures.swell(waveHeight: 0.79))
        XCTAssertTrue(rule.blockers(tooSmall).contains(.waveTooSmall))

        let tooLarge = conditions(at: noon, swell: DecisionFixtures.swell(waveHeight: 2.51))
        XCTAssertTrue(rule.blockers(tooLarge).contains(.waveTooLarge))

        let tooShort = conditions(at: noon, swell: DecisionFixtures.swell(period: 7.9))
        XCTAssertTrue(rule.blockers(tooShort).contains(.wavePeriod))

        let tooLong = conditions(at: noon, swell: DecisionFixtures.swell(period: 14.1))
        XCTAssertTrue(rule.blockers(tooLong).contains(.wavePeriod))

        let tooWindy = conditions(at: noon, weather: DecisionFixtures.weather(windSpeed: 20))
        XCTAssertTrue(rule.blockers(tooWindy).contains(.wind))

        let badSwellDirection = conditions(
            at: noon,
            swell: DecisionFixtures.swell(directionDegrees: 90))
        XCTAssertTrue(rule.blockers(badSwellDirection).contains(.swellDirection))

        let unknownOrientation = conditions(
            at: noon,
            spot: Spot(
                id: "no-orientation",
                name: "No orientation",
                region: .bassin,
                coordinate: DecisionFixtures.arcachon.coordinate,
                tideStation: DecisionFixtures.arcachon.tideStation,
                supportedActivities: [.surfing],
                timezone: DecisionFixtures.timezone,
                coastOrientationDegrees: nil))
        XCTAssertTrue(rule.blockers(unknownOrientation).contains(.dataUnavailable))
    }

    // MARK: Bateau

    func testBoatingGates() throws {
        let rule = try rule(.boating)

        let atGate = conditions(
            at: noon,
            weather: DecisionFixtures.weather(windSpeed: 19.9, visibility: 20000),
            swell: DecisionFixtures.swell(waveHeight: 0.99))
        XCTAssertEqual(rule.blockers(atGate), [])

        let tooWindy = conditions(
            at: noon,
            weather: DecisionFixtures.weather(windSpeed: 20),
            swell: DecisionFixtures.swell(waveHeight: 0.5))
        XCTAssertTrue(rule.blockers(tooWindy).contains(.wind))

        let tooMuchSwell = conditions(
            at: noon,
            weather: DecisionFixtures.weather(windSpeed: 12),
            swell: DecisionFixtures.swell(waveHeight: 1.0))
        XCTAssertTrue(rule.blockers(tooMuchSwell).contains(.swellTooLarge))

        let poorVisibility = conditions(
            at: noon,
            weather: DecisionFixtures.weather(windSpeed: 12, visibility: 499),
            swell: DecisionFixtures.swell(waveHeight: 0.5))
        XCTAssertTrue(rule.blockers(poorVisibility).contains(.visibility))

        let noCurve = conditions(
            at: noon,
            tide: TideState(
                current: TideEvent(time: noon.addingTimeInterval(-3600), kind: .low, height: 0.4),
                next: TideEvent(time: noon.addingTimeInterval(320 * 60), kind: .high, height: 4.4),
                coefficient: 95,
                curve: []),
            weather: DecisionFixtures.weather(windSpeed: 12),
            swell: DecisionFixtures.swell(waveHeight: 0.5))
        XCTAssertTrue(rule.blockers(noCurve).contains(.dataUnavailable))
    }

    func testBoatingUsesTheConservativeDefaultDraught() throws {
        let rule = try rule(.boating)
        let spotWithoutDraught = Spot(
            id: "no-draught",
            name: "No draught",
            region: .bassin,
            coordinate: DecisionFixtures.arcachon.coordinate,
            tideStation: DecisionFixtures.arcachon.tideStation,
            supportedActivities: [.boating],
            timezone: DecisionFixtures.timezone,
            minimumWaterHeight: nil)
        let shallow = conditions(
            at: noon,
            tide: DecisionFixtures.tide(
                at: noon,
                currentHeight: 0.4,
                nextHeight: 4.4,
                minutesSinceCurrent: 0,
                minutesToNext: 300),
            weather: DecisionFixtures.weather(windSpeed: 12),
            swell: DecisionFixtures.swell(waveHeight: 0.5),
            spot: spotWithoutDraught)

        XCTAssertTrue(rule.blockers(shallow).contains(.waterLevel))
    }

    // MARK: Balade

    func testWalkingGates() throws {
        let rule = try rule(.walking)

        let atGate = conditions(
            at: noon,
            weather: DecisionFixtures.weather(temperature: 8, precipitationChance: 0, windSpeed: 29.9))
        XCTAssertEqual(rule.blockers(atGate), [])

        let tooCold = conditions(at: noon, weather: DecisionFixtures.weather(temperature: 7.9))
        XCTAssertTrue(rule.blockers(tooCold).contains(.temperature))

        let tooHot = conditions(at: noon, weather: DecisionFixtures.weather(temperature: 30.1))
        XCTAssertTrue(rule.blockers(tooHot).contains(.temperature))

        let tooWindy = conditions(at: noon, weather: DecisionFixtures.weather(windSpeed: 30))
        XCTAssertTrue(rule.blockers(tooWindy).contains(.wind))

        let rainy = conditions(at: noon, weather: DecisionFixtures.weather(precipitationChance: 0.6))
        XCTAssertTrue(rule.blockers(rainy).contains(.rain))
    }

    // MARK: Baignade

    func testSwimmingGates() throws {
        let rule = try rule(.swimming)

        let atGate = conditions(
            at: summerNoon,
            tide: DecisionFixtures.tide(at: summerNoon, coefficient: 80),
            weather: DecisionFixtures.weather(temperature: 20, windSpeed: 19.9),
            swell: DecisionFixtures.swell(waveHeight: 0.79, seaSurfaceTemperature: 18))
        XCTAssertEqual(rule.blockers(atGate), [])

        let coldWater = conditions(
            at: summerNoon,
            tide: DecisionFixtures.tide(at: summerNoon, coefficient: 80),
            weather: DecisionFixtures.weather(temperature: 24),
            swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: 17.9))
        XCTAssertTrue(rule.blockers(coldWater).contains(.waterTemperature))

        let coldAir = conditions(
            at: summerNoon,
            tide: DecisionFixtures.tide(at: summerNoon, coefficient: 80),
            weather: DecisionFixtures.weather(temperature: 19.9),
            swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: 20))
        XCTAssertTrue(rule.blockers(coldAir).contains(.temperature))

        let tooWindy = conditions(
            at: summerNoon,
            tide: DecisionFixtures.tide(at: summerNoon, coefficient: 80),
            weather: DecisionFixtures.weather(temperature: 24, windSpeed: 20),
            swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: 20))
        XCTAssertTrue(rule.blockers(tooWindy).contains(.wind))

        let tooMuchSwell = conditions(
            at: summerNoon,
            tide: DecisionFixtures.tide(at: summerNoon, coefficient: 80),
            weather: DecisionFixtures.weather(temperature: 24),
            swell: DecisionFixtures.swell(waveHeight: 0.8, seaSurfaceTemperature: 20))
        XCTAssertTrue(rule.blockers(tooMuchSwell).contains(.swellTooLarge))

        let missingWaterTemperature = conditions(
            at: summerNoon,
            tide: DecisionFixtures.tide(at: summerNoon, coefficient: 80),
            weather: DecisionFixtures.weather(temperature: 24),
            swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: nil))
        XCTAssertTrue(rule.blockers(missingWaterTemperature).contains(.dataUnavailable))
    }

    // MARK: Missing-data guards across the board

    func testSwimmingSpringTideWithoutTideEventsIsBlocked() throws {
        let rule = try rule(.swimming)
        let noEvents = conditions(
            at: summerNoon,
            tide: TideState(current: nil, next: nil, coefficient: 105, curve: []),
            weather: DecisionFixtures.weather(temperature: 24, windSpeed: 10),
            swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: 20))

        XCTAssertTrue(rule.blockers(noEvents).contains(.currentDataUnavailable))
        XCTAssertEqual(rule.score(noEvents), 0.96, accuracy: 1e-12)

        let decision = DecisionEngine().decide(activity: .swimming, conditions: noEvents)
        XCTAssertFalse(decision.go)
        XCTAssertTrue(decision.isDataUnavailable)
    }

    func testSwimmingSpringTideWithNonBracketingEventsIsBlocked() throws {
        let rule = try rule(.swimming)
        // Events exist but both are after the decision instant, so the phase
        // cannot be computed.
        let nonBracketing = TideState(
            current: TideEvent(time: summerNoon.addingTimeInterval(3600), kind: .low, height: 0.4),
            next: TideEvent(time: summerNoon.addingTimeInterval(3 * 3600), kind: .high, height: 4.4),
            coefficient: 105,
            curve: [])
        let nonBracketingConditions = conditions(
            at: summerNoon,
            tide: nonBracketing,
            weather: DecisionFixtures.weather(temperature: 24, windSpeed: 10),
            swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: 20))

        XCTAssertTrue(
            rule.blockers(nonBracketingConditions).contains(.currentDataUnavailable))
        XCTAssertEqual(rule.score(nonBracketingConditions), 0.96, accuracy: 1e-12)
        XCTAssertFalse(DecisionEngine().decide(activity: .swimming, conditions: nonBracketingConditions).go)
    }

    func testSwimmingSpringTideInTheStrongCurrentBandIsBlocked() throws {
        let rule = try rule(.swimming)
        let strongCurrent = conditions(
            at: summerNoon,
            tide: DecisionFixtures.tide(
                at: summerNoon,
                coefficient: 105,
                minutesSinceCurrent: 180,
                minutesToNext: 180),
            weather: DecisionFixtures.weather(temperature: 24, windSpeed: 10),
            swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: 20),
            spot: DecisionFixtures.swimmingStrongSpot)

        XCTAssertTrue(rule.blockers(strongCurrent).contains(.strongCurrent))
        XCTAssertFalse(rule.blockers(strongCurrent).contains(.dataUnavailable))
        XCTAssertEqual(rule.score(strongCurrent), 0.96, accuracy: 1e-12)
        XCTAssertFalse(DecisionEngine().decide(activity: .swimming, conditions: strongCurrent).go)
    }

    func testSwimmingLowRangeDoesNotRequireTheCurrentPhase() throws {
        let rule = try rule(.swimming)
        // Range 4.0 m < the fixture lowBelow 4.5 m: the level is low, and a
        // missing current/next event must not turn it into unknown.
        let lowRange = conditions(
            at: summerNoon,
            tide: TideState(
                current: nil,
                next: nil,
                coefficient: 80,
                coefficientSource: .nationalBrest,
                coefficientValidated: true,
                curve: [
                    TidePoint(time: summerNoon.addingTimeInterval(-3600), height: 0.4),
                    TidePoint(time: summerNoon, height: 4.4)
                ]),
            weather: DecisionFixtures.weather(temperature: 24, windSpeed: 10),
            swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: 20))

        XCTAssertEqual(rule.blockers(lowRange), [])
        XCTAssertEqual(rule.score(lowRange), 1, accuracy: 1e-12)
    }

    func testMissingSafetyDataNeverProducesAGo() {
        let engine = DecisionEngine()
        let missingWaterTemperature = conditions(
            at: summerNoon,
            tide: DecisionFixtures.tide(at: summerNoon, coefficient: 80),
            weather: DecisionFixtures.weather(temperature: 24),
            swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: nil))

        let decision = engine.decide(activity: .swimming, conditions: missingWaterTemperature)
        XCTAssertFalse(decision.go)
        XCTAssertEqual(decision.reason, "Données indisponibles.")
    }

    // MARK: Z23 — coefficient scale

    func testShoreFishingFailsClosedWithoutTheNationalCoefficient() throws {
        let rule = try rule(.shoreFishing)
        let localProxy = conditions(
            at: noon,
            tide: DecisionFixtures.tide(
                at: noon,
                coefficient: 95,
                coefficientSource: .localProxy,
                coefficientValidated: false),
            weather: DecisionFixtures.weather(windSpeed: 10))

        XCTAssertTrue(rule.blockers(localProxy).contains(.dataUnavailable))
    }

    func testSwimmingIgnoresTheUnvalidatedNationalCoefficient() throws {
        let rule = try rule(.swimming)
        // The level now depends on the local range, not on the national
        // coefficient: an unvalidated coefficient must not mute the activity.
        let unvalidated = conditions(
            at: summerNoon,
            tide: DecisionFixtures.tide(
                at: summerNoon,
                coefficient: 95,
                coefficientValidated: false),
            weather: DecisionFixtures.weather(temperature: 24, windSpeed: 10),
            swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: 20))

        XCTAssertFalse(rule.blockers(unvalidated).contains(.dataUnavailable))
    }
}
