@testable import EstranCore
import XCTest

/// The rain rule (owner decision 2026-11-12): light rain/drizzle is a small
/// score penalty with a jacket caution, never a blocker; franc rain, showers and
/// thunderstorms still force a `Non`.
final class RainRuleTests: XCTestCase {
    private let noon = DecisionFixtures.date("2026-06-21T12:00:00Z")

    private func conditions(
        condition: WeatherCondition = .clear,
        precipitationChance: Double = 0) -> Conditions
    {
        // A spot with surf, and weather otherwise calm, so only the rain gate is
        // in play.
        let weather = DecisionFixtures.weather(
            condition: condition,
            precipitationChance: precipitationChance,
            windSpeed: 10,
            windGust: 15)
        return DecisionFixtures.conditions(
            at: noon,
            tide: DecisionFixtures.tide(at: noon, coefficient: 95),
            weather: weather)
    }

    private func decision(_ activity: Activity, _ conditions: Conditions) -> GoDecision {
        DecisionEngine().decide(activity: activity, conditions: conditions)
    }

    func testDrizzleDoesNotBlockFishingOrWalking() {
        for activity in [Activity.shoreFishing, .walking] {
            let drizzle = conditions(condition: .drizzle, precipitationChance: 0.3)
            let result = decision(activity, drizzle)
            XCTAssertFalse(result.blockers.contains(.rain), "\(activity) must not block on drizzle")
            XCTAssertFalse(result.blockers.contains(.storm), "\(activity) must not storm on drizzle")
            XCTAssertTrue(result.go, "\(activity) should stay go-able under drizzle")
            XCTAssertEqual(result.caution, ActivityCaution.rainJacket)
        }
    }

    func testDrizzleDoesNotAffectOtherActivities() {
        for activity in [Activity.surfing, .boating, .swimming] {
            let drizzle = conditions(condition: .drizzle, precipitationChance: 0.3)
            let result = decision(activity, drizzle)
            XCTAssertNil(result.caution, "\(activity) must not carry the jacket caution")
        }
    }

    func testShowersBlockFishingAndWalking() {
        for activity in [Activity.shoreFishing, .walking] {
            let showers = conditions(condition: .showers, precipitationChance: 0.5)
            let result = decision(activity, showers)
            XCTAssertTrue(result.blockers.contains(.rain), "\(activity) must block on showers")
        }
    }

    func testFrancRainBlocksFishingAndWalking() {
        for activity in [Activity.shoreFishing, .walking] {
            let rain = conditions(condition: .rain, precipitationChance: 0.7)
            let result = decision(activity, rain)
            XCTAssertTrue(result.blockers.contains(.rain), "\(activity) must block on franc rain")
        }
    }

    func testThunderstormIsStorm() {
        for activity in [Activity.shoreFishing, .walking] {
            let storm = conditions(condition: .thunderstorm, precipitationChance: 0.9)
            let result = decision(activity, storm)
            XCTAssertTrue(result.blockers.contains(.storm), "\(activity) must storm on thunderstorm")
        }
    }

    func testHighChanceWithDryConditionBlocks() {
        // A dry condition with a very high chance still blocks (fail closed),
        // while a middling chance only warns.
        for activity in [Activity.shoreFishing, .walking] {
            let likely = conditions(condition: .cloudy, precipitationChance: 0.85)
            XCTAssertTrue(
                decision(activity, likely).blockers.contains(.rain),
                "\(activity) must block at >= 0.8 chance")

            let middling = conditions(condition: .cloudy, precipitationChance: 0.6)
            let result = decision(activity, middling)
            XCTAssertFalse(result.blockers.contains(.rain), "\(activity) must not block at 0.6")
            XCTAssertEqual(result.caution, ActivityCaution.rainJacket)
        }
    }
}
