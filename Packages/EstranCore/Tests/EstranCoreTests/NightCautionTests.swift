@testable import EstranCore
import XCTest

/// Night for pêche à pied, boating and balade (owner decisions 2026-11-12 and
/// 2026-11-13): it is not forbidden and never a blocker. It lowers the score a
/// little and adds a caution; Surf and Baignade keep their previous behaviour.
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

    /// Balade joined the night-tolerant group on 2026-11-13 (`W-FIX8`): its
    /// full coverage lives in `WalkingNightCautionTests`; this pins the shift
    /// so nobody restores the old "no night caution" assumption here.
    func testWalkingIsNightTolerantSince20261113() {
        let result = decision(.walking, conditions(at: night))

        XCTAssertFalse(result.blockers.contains(.night), "night never blocks balade")
        XCTAssertEqual(result.caution, ActivityCaution.nightWalking)
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

    // MARK: - The tide envelope is not the clock (W-NIGHTFIX)

    /// Pointe de Grave on 13 November 2026, in local time (Europe/Paris, CET).
    private func graveDate(localHour: Int, localMinute: Int = 0) -> Date {
        // Local time is UTC+1 in November: 09:08 local is 08:08Z.
        let startOfDay = DecisionFixtures.date("2026-11-13T00:00:00Z")
        return startOfDay.addingTimeInterval(Double(localHour - 1) * 3600
            + Double(localMinute) * 60)
    }

    /// The spot's `u_t` is 75 min: the regression under test.
    private var grave: Spot {
        SpotCatalog.pointeDeGrave
    }

    private func graveConditions(at date: Date) -> Conditions {
        DecisionFixtures.conditions(
            at: date,
            tide: DecisionFixtures.tide(at: date, coefficient: 95, minutesSinceCurrent: 60),
            weather: DecisionFixtures.weather(windSpeed: 10, windGust: 15),
            swell: DecisionFixtures.swell(waveHeight: 0.6, period: 8),
            spot: grave)
    }

    func testFishingAt0908AfterSunriseCarriesNoNightCaution() {
        let morning = graveDate(localHour: 9, localMinute: 8)

        // The regression: the sun is up at the decision instant, and the
        // instant 75 min earlier (the tide's own uncertainty) is still dark.
        XCTAssertTrue(SolarDaylight.isDaylight(at: morning, coordinate: grave.coordinate))
        XCTAssertFalse(
            SolarDaylight.isDaylight(
                at: morning.addingTimeInterval(-75 * 60),
                coordinate: grave.coordinate),
            "u_t reaches into the dark; that is why the envelope used to say night")

        let result = decision(.shoreFishing, graveConditions(at: morning))

        XCTAssertNil(result.caution, "09:08 after sunrise is not night")
    }

    func testFishingScoresFullInTheMorningAfterSunrise() {
        let morning = decision(.shoreFishing, graveConditions(at: graveDate(localHour: 9, localMinute: 8)))
        let noon = decision(.shoreFishing, graveConditions(at: graveDate(localHour: 12)))

        XCTAssertEqual(
            morning.score,
            noon.score,
            accuracy: 1e-12,
            "no night penalty after sunrise")
    }

    func testFishingAt0700BeforeSunriseCarriesTheCaution() {
        let early = graveDate(localHour: 7)

        XCTAssertFalse(SolarDaylight.isDaylight(at: early, coordinate: grave.coordinate))

        let result = decision(.shoreFishing, graveConditions(at: early))

        XCTAssertEqual(result.caution, ActivityCaution.nightFishing)
    }

    func testWindowCrossingSunsetCarriesTheNightCaution() {
        let window = DateInterval(
            start: graveDate(localHour: 16),
            end: graveDate(localHour: 19))

        XCTAssertEqual(
            ActivityCaution.nightCaution(
                activity: .shoreFishing,
                window: window,
                coordinate: grave.coordinate),
            ActivityCaution.nightFishing)
    }

    func testDaylightWindowCarriesNoNightCaution() {
        let window = DateInterval(
            start: graveDate(localHour: 10),
            end: graveDate(localHour: 13))

        XCTAssertNil(
            ActivityCaution.nightCaution(
                activity: .shoreFishing,
                window: window,
                coordinate: grave.coordinate))
    }

    func testWindowCautionIsNilWithoutAWindow() {
        // The « Créneaux » card that says « Pas de créneau d'ici 48 h » must not
        // repeat the current instant's caution under it.
        XCTAssertNil(
            ActivityCaution.windowCaution(
                activity: .shoreFishing,
                window: nil,
                spot: grave,
                weather: DecisionFixtures.weather()))
    }

    func testWindowCautionComposesNightThenTheSpotCaution() {
        let window = DateInterval(
            start: graveDate(localHour: 16),
            end: graveDate(localHour: 19))

        XCTAssertEqual(
            ActivityCaution.windowCaution(
                activity: .boating,
                window: window,
                spot: SpotCatalog.arcachonEyrac,
                weather: DecisionFixtures.weather()),
            "\(ActivityCaution.nightBoating) \(ActivityCaution.boatingPasses)")
    }
}
