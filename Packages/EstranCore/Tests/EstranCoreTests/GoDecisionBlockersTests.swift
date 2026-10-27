@testable import EstranCore
import XCTest

/// The UI needs to tell « Non » from « Données indisponibles ». `GoDecision`
/// carries its blockers so every surface renders the same state instead of
/// re-deriving it from the rule.
final class GoDecisionBlockersTests: XCTestCase {
    private func conditions(tide: TideState, at date: Date) -> Conditions {
        Conditions(
            spot: SpotCatalog.arcachonEyrac,
            at: date,
            tide: tide,
            weather: DecisionFixtures.weather(),
            swell: DecisionFixtures.swell())
    }

    func testShippedSwimmingUsesTheCalibratedRange() async throws {
        let model = try ShippedTideModel.load()
        let engine = try model.engine()
        let now = Date()
        let tide = try await engine.state(for: "190", at: now)
        XCTAssertNotNil(SpotCatalog.arcachonEyrac.swimmingRange)
        XCTAssertNotNil(tide.dailyRange)

        let decision = DecisionEngine().decide(
            activity: .swimming,
            conditions: conditions(tide: tide, at: now))
        let level = SwimmingRiskLevel(decision: decision)

        XCTAssertNotEqual(level, .unknown, "the shipped range must produce a level")
        XCTAssertFalse(level.title.contains("Oui"))
        XCTAssertFalse(level.title.contains("Non"))
    }

    func testANormalRefusalIsNotReportedAsDataUnavailable() {
        let now = DecisionFixtures.date("2025-06-15T12:00:00Z")
        // A national coefficient, heavy onshore wind: a real refusal, not a gap.
        let tide = DecisionFixtures.tide(at: now, coefficient: 95)
        let weather = DecisionFixtures.weather(windSpeed: 45, windGust: 60)
        let conditions = Conditions(
            spot: SpotCatalog.arcachonEyrac,
            at: now,
            tide: tide,
            weather: weather,
            swell: DecisionFixtures.swell(waveHeight: 2.4))

        let decision = DecisionEngine().decide(activity: .boating, conditions: conditions)

        XCTAssertFalse(decision.go)
        XCTAssertFalse(decision.isDataUnavailable)
        XCTAssertFalse(decision.blockers.isEmpty)
    }

    func testBlockersSurviveCodableRoundTrip() throws {
        let now = DecisionFixtures.date("2025-06-15T12:00:00Z")
        let decision = GoDecision(
            activity: .swimming,
            spot: SpotCatalog.arcachonEyrac,
            go: false,
            score: 0.1,
            reason: "Données indisponibles.",
            reasonSource: .template,
            nextGoodWindow: nil,
            computedAt: now,
            blockers: [.dataUnavailable, .strongCurrent])

        let data = try JSONEncoder().encode(decision)
        let decoded = try JSONDecoder().decode(GoDecision.self, from: data)
        XCTAssertEqual(decoded.blockers, [.dataUnavailable, .strongCurrent])
        XCTAssertTrue(decoded.isDataUnavailable)
    }
}
