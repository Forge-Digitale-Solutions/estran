@testable import EstranCore
import XCTest

/// Night for balade (owner decision 2026-11-13, option 2): the same mechanism
/// as pêche à pied and bateau. Night is not a blocker, the score is multiplied
/// by `RuleSignals.nightScorePenalty`, and the verdict carries « De nuit :
/// lampe frontale. » — on the instant for the answer card and on any window
/// that reaches into the dark. Swimming keeps its own `.night` gate.
final class WalkingNightCautionTests: XCTestCase {
    /// 03:00 in Arcachon on the longest day: unambiguously night.
    private let night = DecisionFixtures.date("2026-06-21T01:00:00Z")
    /// 12:00 in Arcachon: unambiguously day.
    private let noon = DecisionFixtures.date("2026-06-21T10:00:00Z")

    private func conditions(
        at date: Date,
        weather: WeatherNow = DecisionFixtures.weather(windSpeed: 10, windGust: 15)) -> Conditions
    {
        DecisionFixtures.conditions(
            at: date,
            tide: DecisionFixtures.tide(
                at: date,
                coefficient: 95,
                minutesSinceCurrent: 60),
            weather: weather)
    }

    private func decision(_ conditions: Conditions) -> GoDecision {
        DecisionEngine().decide(activity: .walking, conditions: conditions)
    }

    // MARK: - The instant

    func testWalkingAtNightIsNotBlockedAndCarriesTheCaution() {
        let result = decision(conditions(at: night))

        XCTAssertFalse(result.blockers.contains(.night), "night is not a blocker for balade")
        XCTAssertTrue(result.go, "a calm night stays a Oui for balade")
        XCTAssertEqual(result.caution, ActivityCaution.nightWalking)
        XCTAssertEqual(ActivityCaution.nightWalking, "De nuit : lampe frontale.")
    }

    func testWalkingScoresLowerAtNightThanByDay() {
        let day = decision(conditions(at: noon))
        let dark = decision(conditions(at: night))

        XCTAssertNil(day.caution, "no night caution in daylight")
        XCTAssertLessThan(dark.score, day.score)
        XCTAssertEqual(dark.score, day.score * RuleSignals.nightScorePenalty, accuracy: 1e-9)
    }

    func testWalkingNightComesBeforeTheRainCaution() {
        let drizzle = DecisionFixtures.weather(
            condition: .drizzle,
            precipitationChance: 0.3,
            windSpeed: 10,
            windGust: 15)
        let result = decision(conditions(at: night, weather: drizzle))

        XCTAssertEqual(
            result.caution,
            "\(ActivityCaution.nightWalking) \(ActivityCaution.rainJacket)")
    }

    // MARK: - The window

    func testWindowCrossingSunsetCarriesTheWalkingCaution() {
        let window = DateInterval(
            start: graveDate(localHour: 16),
            end: graveDate(localHour: 19))

        XCTAssertEqual(
            ActivityCaution.nightCaution(
                activity: .walking,
                window: window,
                coordinate: grave.coordinate),
            ActivityCaution.nightWalking)
    }

    func testDaylightWindowCarriesNoWalkingCaution() {
        let window = DateInterval(
            start: graveDate(localHour: 10),
            end: graveDate(localHour: 13))

        XCTAssertNil(
            ActivityCaution.nightCaution(
                activity: .walking,
                window: window,
                coordinate: grave.coordinate))
    }

    func testWalkingWindowCautionIsNilWithoutAWindow() {
        // The « Créneaux » card that says « Pas de créneau d'ici 48 h » must not
        // repeat the current instant's caution under it.
        XCTAssertNil(
            ActivityCaution.windowCaution(
                activity: .walking,
                window: nil,
                spot: grave,
                weather: DecisionFixtures.weather()))
    }

    func testWalkingWindowCautionComposesNightThenTheRainReminder() {
        let window = DateInterval(
            start: graveDate(localHour: 16),
            end: graveDate(localHour: 19))
        let drizzle = DecisionFixtures.weather(
            condition: .drizzle,
            precipitationChance: 0.3)

        XCTAssertEqual(
            ActivityCaution.windowCaution(
                activity: .walking,
                window: window,
                spot: SpotCatalog.arcachonEyrac,
                weather: drizzle),
            "\(ActivityCaution.nightWalking) \(ActivityCaution.rainJacket)",
            "balade has no permanent spot caution, night still comes first")
    }

    // MARK: - The tide envelope is not the clock (W-NIGHTFIX)

    /// Pointe de Grave on 13 November 2026, in local time (Europe/Paris, CET).
    private func graveDate(localHour: Int, localMinute: Int = 0) -> Date {
        // Local time is UTC+1 in November: 09:08 local is 08:08Z.
        let startOfDay = DecisionFixtures.date("2026-11-13T00:00:00Z")
        return startOfDay.addingTimeInterval(Double(localHour - 1) * 3600
            + Double(localMinute) * 60)
    }

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

    func testWalkingAt0908AfterSunriseCarriesNoNightCaution() {
        let morning = graveDate(localHour: 9, localMinute: 8)

        XCTAssertTrue(SolarDaylight.isDaylight(at: morning, coordinate: grave.coordinate))

        let result = DecisionEngine().decide(
            activity: .walking,
            conditions: graveConditions(at: morning))

        XCTAssertNil(result.caution, "09:08 after sunrise is not night")
    }

    func testWalkingScoresFullInTheMorningAfterSunrise() {
        let morning = DecisionEngine().decide(
            activity: .walking,
            conditions: graveConditions(at: graveDate(localHour: 9, localMinute: 8)))
        let noon = DecisionEngine().decide(
            activity: .walking,
            conditions: graveConditions(at: graveDate(localHour: 12)))

        XCTAssertEqual(
            morning.score,
            noon.score,
            accuracy: 1e-12,
            "no night penalty after sunrise")
    }

    func testWalkingAt0700BeforeSunriseCarriesTheCaution() {
        let early = graveDate(localHour: 7)

        XCTAssertFalse(SolarDaylight.isDaylight(at: early, coordinate: grave.coordinate))

        let result = DecisionEngine().decide(
            activity: .walking,
            conditions: graveConditions(at: early))

        XCTAssertEqual(result.caution, ActivityCaution.nightWalking)
    }

    // MARK: - Neighbours untouched

    func testSurfKeepsNoNightCaution() {
        let result = DecisionEngine().decide(
            activity: .surfing,
            conditions: graveConditions(at: graveDate(localHour: 7)))

        XCTAssertNil(result.caution)
    }
}
