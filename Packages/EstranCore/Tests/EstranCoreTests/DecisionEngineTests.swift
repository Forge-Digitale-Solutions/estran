@testable import EstranCore
import XCTest

private struct StubRule: ActivityRule {
    let activity: Activity = .walking
    let threshold = 0.5

    func score(_ conditions: Conditions) -> Double {
        conditions.weather.temperature / 40
    }

    func blockers(_: Conditions) -> [ActivityBlocker] {
        []
    }
}

/// Stub whose score and blockers can diverge: a high score with a blocker must
/// still break a window (B1 regression).
private struct GatedStubRule: ActivityRule {
    let activity: Activity = .walking
    let threshold = 0.5

    func score(_ conditions: Conditions) -> Double {
        conditions.weather.temperature / 40
    }

    func blockers(_ conditions: Conditions) -> [ActivityBlocker] {
        conditions.weather.wind.speed >= 20 ? [.wind] : []
    }
}

final class DecisionEngineTests: XCTestCase {
    private let start = DecisionFixtures.date("2026-06-21T08:00:00Z")
    private let step: TimeInterval = 30 * 60

    private func stubConditions(temperature: Double, offset: TimeInterval) -> Conditions {
        let at = start.addingTimeInterval(offset)
        return DecisionFixtures.conditions(
            at: at,
            tide: DecisionFixtures.tide(at: at),
            weather: DecisionFixtures.weather(temperature: temperature))
    }

    private func gatedConditions(
        temperature: Double,
        windSpeed: Double,
        offset: TimeInterval) -> Conditions
    {
        let at = start.addingTimeInterval(offset)
        return DecisionFixtures.conditions(
            at: at,
            tide: DecisionFixtures.tide(at: at),
            weather: DecisionFixtures.weather(temperature: temperature, windSpeed: windSpeed))
    }

    func testDefaultEngineCoversEveryActivity() {
        let engine = DecisionEngine()
        for activity in Activity.allCases {
            XCTAssertNotNil(engine.rule(for: activity))
        }
    }

    func testDecideIsDeterministicAndBounded() {
        let engine = DecisionEngine()
        let conditions = DecisionFixtures.conditions(
            at: start,
            tide: DecisionFixtures.tide(at: start, coefficient: 95),
            weather: DecisionFixtures.weather(windSpeed: 8))

        for activity in Activity.allCases {
            let first = engine.decide(activity: activity, conditions: conditions)
            let second = engine.decide(activity: activity, conditions: conditions)
            XCTAssertEqual(first, second)
            XCTAssertGreaterThanOrEqual(first.score, 0)
            XCTAssertLessThanOrEqual(first.score, 1)
            XCTAssertEqual(first.reasonSource, .template)
            XCTAssertEqual(first.computedAt, conditions.at)
        }
    }

    func testDecideFillsTheNextWindowFromTheForecast() {
        let engine = DecisionEngine(rules: [StubRule()])
        let now = stubConditions(temperature: 0, offset: 0)
        let forecast = [
            now,
            stubConditions(temperature: 0, offset: step),
            stubConditions(temperature: 40, offset: step * 2),
            stubConditions(temperature: 40, offset: step * 3),
            stubConditions(temperature: 40, offset: step * 4)
        ]

        let decision = engine.decide(activity: .walking, conditions: now, forecast: forecast)
        XCTAssertFalse(decision.go)
        XCTAssertEqual(decision.nextGoodWindow?.start, start.addingTimeInterval(step * 2))
        XCTAssertEqual(decision.nextGoodWindow?.end, start.addingTimeInterval(step * 5))
    }

    func testNextWindowNeverStartsBeforeTheDecisionInstant() {
        let engine = DecisionEngine(rules: [StubRule()])
        let now = stubConditions(temperature: 0, offset: 0)
        let forecast = [
            stubConditions(temperature: 40, offset: step),
            stubConditions(temperature: 40, offset: step * 2),
            stubConditions(temperature: 40, offset: step * 3)
        ]

        let decision = engine.decide(activity: .walking, conditions: now, forecast: forecast)
        XCTAssertEqual(decision.nextGoodWindow?.start, start.addingTimeInterval(step))
    }

    func testGoodDecisionHasNoNextWindow() {
        let engine = DecisionEngine(rules: [StubRule()])
        let now = stubConditions(temperature: 40, offset: 0)
        let decision = engine.decide(activity: .walking, conditions: now)
        XCTAssertTrue(decision.go)
        XCTAssertNil(decision.nextGoodWindow)
        XCTAssertEqual(decision.reason, "C'est bon pour la balade.")
    }

    func testUnknownActivityIsNotGo() {
        let engine = DecisionEngine(rules: [])
        let conditions = stubConditions(temperature: 40, offset: 0)
        let decision = engine.decide(activity: .walking, conditions: conditions)
        XCTAssertFalse(decision.go)
        XCTAssertEqual(decision.score, 0)
        XCTAssertEqual(decision.reason, "Activité indisponible.")
        XCTAssertNil(decision.nextGoodWindow)
    }

    func testWindowsAggregateTheRun() {
        let engine = DecisionEngine(rules: [StubRule()])
        let forecast = [
            stubConditions(temperature: 0, offset: 0),
            stubConditions(temperature: 40, offset: step),
            stubConditions(temperature: 40, offset: step * 2),
            stubConditions(temperature: 40, offset: step * 3),
            stubConditions(temperature: 0, offset: step * 4)
        ]

        let slots = engine.windows(activity: .walking, over: forecast)
        XCTAssertEqual(slots.count, 1)
        XCTAssertEqual(slots.first?.window.start, start.addingTimeInterval(step))
        XCTAssertEqual(slots.first?.window.end, start.addingTimeInterval(step * 4))
        XCTAssertEqual(slots.first?.score ?? -1, 1, accuracy: 1e-12)
        XCTAssertEqual(slots.first?.go, true)
    }

    func testWindowsWithEmptyForecast() {
        let engine = DecisionEngine()
        XCTAssertTrue(engine.windows(activity: .shoreFishing, over: []).isEmpty)
    }

    func testBlockedSampleSplitsWindowsEvenWithAHighScore() {
        let engine = DecisionEngine(rules: [GatedStubRule()])
        // Two good runs of four samples, separated by one blocked sample whose
        // score is still above the threshold.
        let forecast = (0 ..< 9).map { index in
            gatedConditions(
                temperature: 40,
                windSpeed: index == 4 ? 25 : 0,
                offset: Double(index) * step)
        }

        let slots = engine.windows(activity: .walking, over: forecast)
        XCTAssertEqual(slots.count, 2)
        XCTAssertEqual(slots[0].window.start, start)
        XCTAssertEqual(slots[0].window.end, start.addingTimeInterval(step * 4))
        XCTAssertEqual(slots[0].go, true)
        XCTAssertEqual(slots[1].window.start, start.addingTimeInterval(step * 5))
        XCTAssertEqual(slots[1].window.end, start.addingTimeInterval(step * 9))
        XCTAssertEqual(slots[1].go, true)

        for slot in slots {
            XCTAssertFalse(
                slot.window.start <= start.addingTimeInterval(step * 4)
                    && start.addingTimeInterval(step * 4) < slot.window.end,
                "blocked sample leaked into a window")
        }
    }

    func testDecisionAtABlockedSampleDoesNotOfferAWindowStartingNow() {
        let engine = DecisionEngine(rules: [GatedStubRule()])
        let now = gatedConditions(temperature: 40, windSpeed: 25, offset: 0)
        let forecast = [
            now,
            gatedConditions(temperature: 40, windSpeed: 25, offset: step),
            gatedConditions(temperature: 40, windSpeed: 25, offset: step * 2),
            gatedConditions(temperature: 40, windSpeed: 0, offset: step * 3),
            gatedConditions(temperature: 40, windSpeed: 0, offset: step * 4)
        ]

        let decision = engine.decide(activity: .walking, conditions: now, forecast: forecast)
        XCTAssertFalse(decision.go)
        XCTAssertEqual(decision.reason, "Vent trop fort.")
        XCTAssertEqual(decision.nextGoodWindow?.start, start.addingTimeInterval(step * 3))
        XCTAssertEqual(decision.nextGoodWindow?.end, start.addingTimeInterval(step * 5))
    }

    func testBlockedSamplesAloneProduceNoWindow() {
        let engine = DecisionEngine(rules: [GatedStubRule()])
        // A single unblocked sample is shorter than the 1 h minimum, so no slot
        // may be reported even though its score is above the threshold.
        let forecast = (0 ..< 4).map { index in
            gatedConditions(
                temperature: 40,
                windSpeed: index == 1 ? 0 : 25,
                offset: Double(index) * step)
        }

        XCTAssertTrue(engine.windows(activity: .walking, over: forecast).isEmpty)
    }
}
