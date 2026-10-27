@testable import EstranCore
import XCTest

final class RulesTests: XCTestCase {
    private let noon = DecisionFixtures.date("2026-06-21T10:00:00Z")

    func testShoreFishingBlockers() throws {
        let rule = try XCTUnwrap(DecisionEngine().rule(for: .shoreFishing))

        let windy = DecisionFixtures.conditions(
            at: noon,
            tide: DecisionFixtures.tide(at: noon, coefficient: 95),
            weather: DecisionFixtures.weather(windSpeed: 30, windGust: 35))
        XCTAssertTrue(rule.blockers(windy).contains(.wind))

        let rainy = DecisionFixtures.conditions(
            at: noon,
            tide: DecisionFixtures.tide(at: noon, coefficient: 95),
            weather: DecisionFixtures.weather(condition: .rain, precipitationChance: 0.7))
        XCTAssertTrue(rule.blockers(rainy).contains(.rain))

        let lowCoefficient = DecisionFixtures.conditions(
            at: noon,
            tide: DecisionFixtures.tide(at: noon, coefficient: 49))
        XCTAssertTrue(rule.blockers(lowCoefficient).contains(.coefficient))

        let stormy = DecisionFixtures.conditions(
            at: noon,
            tide: DecisionFixtures.tide(at: noon, coefficient: 95),
            weather: DecisionFixtures.weather(windGust: 80))
        XCTAssertTrue(rule.blockers(stormy).contains(.storm))
    }

    func testSurfBlockers() throws {
        let rule = try XCTUnwrap(DecisionEngine().rule(for: .surfing))

        let flat = DecisionFixtures.conditions(
            at: noon,
            tide: DecisionFixtures.tide(at: noon),
            swell: DecisionFixtures.swell(waveHeight: 0.49))
        XCTAssertTrue(rule.blockers(flat).contains(.waveTooSmall))

        let huge = DecisionFixtures.conditions(
            at: noon,
            tide: DecisionFixtures.tide(at: noon),
            swell: DecisionFixtures.swell(waveHeight: 4.0))
        XCTAssertTrue(rule.blockers(huge).contains(.waveTooLarge))
    }

    func testBoatingBlockers() throws {
        let rule = try XCTUnwrap(DecisionEngine().rule(for: .boating))

        let shallow = DecisionFixtures.conditions(
            at: noon,
            tide: DecisionFixtures.tide(
                at: noon,
                currentHeight: 0.2,
                nextHeight: 4.4,
                minutesSinceCurrent: 0,
                minutesToNext: 300),
            weather: DecisionFixtures.weather(windSpeed: 12))
        XCTAssertTrue(rule.blockers(shallow).contains(.waterLevel))

        let rough = DecisionFixtures.conditions(
            at: noon,
            tide: DecisionFixtures.tide(at: noon),
            weather: DecisionFixtures.weather(windSpeed: 26),
            swell: DecisionFixtures.swell(waveHeight: 1.6))
        let blockers = rule.blockers(rough)
        XCTAssertTrue(blockers.contains(.wind))
        XCTAssertTrue(blockers.contains(.swellTooLarge))
    }

    func testWalkingBlockers() throws {
        let rule = try XCTUnwrap(DecisionEngine().rule(for: .walking))

        let windy = DecisionFixtures.conditions(
            at: noon,
            tide: DecisionFixtures.tide(at: noon),
            weather: DecisionFixtures.weather(windSpeed: 40, windGust: 50))
        XCTAssertTrue(rule.blockers(windy).contains(.wind))

        let rainy = DecisionFixtures.conditions(
            at: noon,
            tide: DecisionFixtures.tide(at: noon),
            weather: DecisionFixtures.weather(precipitationChance: 0.6))
        XCTAssertTrue(rule.blockers(rainy).contains(.rain))
    }

    func testSwimmingBlockers() throws {
        let rule = try XCTUnwrap(DecisionEngine().rule(for: .swimming))
        let summerNoon = DecisionFixtures.date("2026-06-21T12:00:00Z")
        let summerNight = DecisionFixtures.date("2026-06-21T01:00:00Z")

        let cold = DecisionFixtures.conditions(
            at: summerNoon,
            tide: DecisionFixtures.tide(at: summerNoon, coefficient: 80),
            weather: DecisionFixtures.weather(temperature: 24),
            swell: DecisionFixtures.swell(seaSurfaceTemperature: 15))
        XCTAssertTrue(rule.blockers(cold).contains(.waterTemperature))

        let night = DecisionFixtures.conditions(
            at: summerNight,
            tide: DecisionFixtures.tide(at: summerNight, coefficient: 80),
            weather: DecisionFixtures.weather(temperature: 24),
            swell: DecisionFixtures.swell(seaSurfaceTemperature: 20))
        XCTAssertTrue(rule.blockers(night).contains(.night))

        let current = DecisionFixtures.conditions(
            at: summerNoon,
            tide: DecisionFixtures.tide(
                at: summerNoon,
                coefficient: 105,
                minutesSinceCurrent: 180,
                minutesToNext: 180),
            weather: DecisionFixtures.weather(temperature: 24),
            swell: DecisionFixtures.swell(seaSurfaceTemperature: 20),
            spot: DecisionFixtures.swimmingStrongSpot)
        XCTAssertTrue(rule.blockers(current).contains(.strongCurrent))
    }

    func testScoresStayBoundedUnderExtremeInputs() throws {
        let engine = DecisionEngine()
        let extremes: [(WeatherNow, Swell, TideState)] = [
            (
                DecisionFixtures.weather(
                    temperature: -50,
                    condition: .thunderstorm,
                    precipitationChance: 1,
                    windSpeed: 200,
                    windGust: 250,
                    visibility: 0),
                DecisionFixtures.swell(waveHeight: 20, period: 30, seaSurfaceTemperature: -5),
                DecisionFixtures.tide(at: noon, coefficient: 120)),
            (
                DecisionFixtures.weather(
                    temperature: 60,
                    condition: .clear,
                    precipitationChance: 0,
                    windSpeed: 0,
                    windGust: 0,
                    visibility: 100_000),
                DecisionFixtures.swell(waveHeight: 0, period: 0, seaSurfaceTemperature: 40),
                DecisionFixtures.tide(at: noon, coefficient: 20))
        ]

        for (weather, swell, tide) in extremes {
            let conditions = DecisionFixtures.conditions(at: noon, tide: tide, weather: weather, swell: swell)
            for activity in Activity.allCases {
                let rule = try XCTUnwrap(engine.rule(for: activity))
                let score = rule.score(conditions)
                XCTAssertTrue(score.isFinite, "\(activity) produced a non-finite score")
                XCTAssertGreaterThanOrEqual(score, 0, "\(activity) scored below 0")
                XCTAssertLessThanOrEqual(score, 1, "\(activity) scored above 1")
            }
        }
    }

    func testEveryDefaultRuleIsRegisteredOnce() {
        let engine = DecisionEngine()
        for activity in Activity.allCases {
            XCTAssertNotNil(engine.rule(for: activity), "missing rule for \(activity)")
        }
        XCTAssertEqual(DecisionEngine.defaultRules.count, Activity.allCases.count)
    }
}
