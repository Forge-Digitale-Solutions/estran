@testable import EstranCore
import XCTest

/// Night for pêche à pied and boating (owner decision 2026-11-12): it is not
/// forbidden and never a blocker. It lowers the score a little and adds a
/// caution; Balade, Surf and Baignade keep their previous behaviour.
final class NightCautionTests: XCTestCase {
    /// 03:00 in Arcachon on the longest day: unambiguously night.
    private let night = DecisionFixtures.date("2026-06-21T01:00:00Z")
    /// 12:00 in Arcachon: unambiguously day.
    private let noon = DecisionFixtures.date("2026-06-21T10:00:00Z")

    private func conditions(
        at date: Date,
        weather: WeatherNow = DecisionFixtures.weather(windSpeed: 10, windGust: 15),
        swell: Swell = DecisionFixtures.swell(waveHeight: 0.6, period: 8)) -> Conditions
    {
        DecisionFixtures.conditions(
            at: date,
            tide: DecisionFixtures.tide(
                at: date,
                coefficient: 95,
                minutesSinceCurrent: 60),
            weather: weather,
            swell: swell)
    }

    private func decision(_ activity: Activity, _ conditions: Conditions) -> GoDecision {
        DecisionEngine().decide(activity: activity, conditions: conditions)
    }

    // MARK: - Pêche à pied

    func testFishingAtNightIsNotBlockedAndCarriesTheCaution() {
        let result = decision(.shoreFishing, conditions(at: night))

        XCTAssertFalse(result.blockers.contains(.night), "night is not a blocker for pêche à pied")
        XCTAssertTrue(result.go, "a good night tide stays a Oui for pêche à pied")
        XCTAssertEqual(result.caution, ActivityCaution.nightFishing)
    }

    func testFishingScoresLowerAtNightThanByDay() {
        let day = decision(.shoreFishing, conditions(at: noon))
        let dark = decision(.shoreFishing, conditions(at: night))

        XCTAssertEqual(day.caution, nil, "no night caution in daylight")
        XCTAssertLessThan(dark.score, day.score)
        XCTAssertEqual(dark.score, day.score * RuleSignals.nightScorePenalty, accuracy: 1e-9)
    }

    // MARK: - Bateau

    func testBoatingAtNightIsNotBlockedAndCarriesTheCaution() {
        let result = decision(.boating, conditions(at: night))

        XCTAssertFalse(result.blockers.contains(.night), "night is not a blocker for boating")
        XCTAssertTrue(result.go, "a calm night stays a Oui for boating")
        XCTAssertEqual(result.caution, ActivityCaution.nightBoating)
    }

    func testBoatingScoresLowerAtNightThanByDay() {
        let day = decision(.boating, conditions(at: noon))
        let dark = decision(.boating, conditions(at: night))

        XCTAssertNil(day.caution, "no night caution in daylight")
        XCTAssertLessThan(dark.score, day.score)
    }

    // MARK: - Composition

    func testNightComesBeforeTheRainCaution() {
        let drizzle = DecisionFixtures.weather(
            condition: .drizzle,
            precipitationChance: 0.3,
            windSpeed: 10,
            windGust: 15)
        let result = decision(.shoreFishing, conditions(at: night, weather: drizzle))

        XCTAssertEqual(
            result.caution,
            "\(ActivityCaution.nightFishing) \(ActivityCaution.rainJacket)")
    }

    func testBassinPassesCautionFollowsTheNightCaution() {
        let result = decision(.boating, conditions(at: night))

        XCTAssertEqual(
            ActivityCaution.combined(result),
            "\(ActivityCaution.nightBoating) \(ActivityCaution.boatingPasses)")
    }

    // MARK: - Untouched activities

    func testWalkingKeepsItsNightBehaviour() {
        let day = decision(.walking, conditions(at: noon))
        let dark = decision(.walking, conditions(at: night))

        XCTAssertEqual(dark.score, day.score, accuracy: 1e-12)
        XCTAssertEqual(dark.go, day.go)
        XCTAssertNil(dark.caution, "balade carries no night caution")
    }

    func testSwimmingKeepsItsNightGate() {
        let warm = DecisionFixtures.weather(temperature: 24, windSpeed: 10)
        let summerNoon = DecisionFixtures.date("2026-06-21T12:00:00Z")
        let day = decision(
            .swimming,
            DecisionFixtures.conditions(
                at: summerNoon,
                tide: DecisionFixtures.tide(at: summerNoon, coefficient: 80, minutesSinceCurrent: 60),
                weather: warm,
                swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: 20)))
        let dark = decision(
            .swimming,
            DecisionFixtures.conditions(
                at: night,
                tide: DecisionFixtures.tide(at: night, coefficient: 80, minutesSinceCurrent: 60),
                weather: warm,
                swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: 20)))

        XCTAssertTrue(day.blockers.isEmpty)
        XCTAssertTrue(dark.blockers.contains(.night), "swimming still refuses the dark")
        XCTAssertNil(dark.caution)
    }

    func testSurfCarriesNoNightCaution() {
        let result = decision(.surfing, conditions(at: night))

        XCTAssertNil(result.caution)
    }
}
