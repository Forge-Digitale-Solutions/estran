@testable import EstranCore
import XCTest

final class GoldenScenariosTests: XCTestCase {
    func testEveryScenarioMatchesItsReference() throws {
        let engine = DecisionEngine()

        for scenario in GoldenScenarios.all {
            let rule = try XCTUnwrap(engine.rule(for: scenario.activity), scenario.name)
            XCTAssertEqual(rule.blockers(scenario.conditions), scenario.expectedBlockers, scenario.name)
            XCTAssertEqual(rule.score(scenario.conditions), scenario.expectedScore, accuracy: 1e-9, scenario.name)

            let decision = engine.decide(activity: scenario.activity, conditions: scenario.conditions)
            XCTAssertEqual(decision.go, scenario.expectedGo, scenario.name)
            XCTAssertEqual(decision.score, scenario.expectedScore, accuracy: 1e-9, scenario.name)
            XCTAssertEqual(decision.reasonSource, .template, scenario.name)

            if scenario.expectedGo {
                XCTAssertTrue(decision.nextGoodWindow == nil, scenario.name)
            } else if let blocker = scenario.expectedBlockers.first {
                XCTAssertEqual(decision.reason, "\(blocker.shortLabel).", scenario.name)
            }
        }
    }
}
