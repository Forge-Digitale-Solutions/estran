@testable import Estran
import EstranCore
import XCTest

/// Guardrail paths for `FoundationModelReasonProvider` with an injected generator.
///
/// These tests never require Apple Intelligence: availability and generation are
/// faked so the simulator stays deterministic.
final class FoundationModelReasonGuardrailTests: XCTestCase {
    func testSwimmingNeverCallsTheGeneratorAndFallsBackToTheTemplate() async {
        let callCount = CallCounter()
        let provider = FoundationModelReasonProvider(
            isModelAvailable: { true },
            generator: { _ in
                await callCount.increment()
                return "Oui, tu peux te baigner."
            })
        let decision = Fixtures.decision(activity: .swimming, go: true)

        let text = await provider.reason(for: decision, conditions: Fixtures.conditions())

        let calls = await callCount.value
        XCTAssertEqual(text, decision.reason, "swimming stays on the deterministic template")
        XCTAssertEqual(calls, 0, "the model is never asked for swimming")
        XCTAssertFalse(text.localizedCaseInsensitiveContains("oui"))
    }

    func testGeneratedOuiForSwimmingIsRejectedByIsAcceptable() {
        let decision = Fixtures.decision(activity: .swimming, go: true)

        XCTAssertFalse(
            FoundationModelReasonProvider.isAcceptable(
                "Oui, tu peux te baigner.",
                for: decision,
                conditions: Fixtures.conditions()),
            "invariant 1 still rejects Oui even if a draft slips through")
    }

    func testGeneratedSHOMClaimFallsBackToTheTemplate() async {
        let decision = Fixtures.decision(activity: .walking, go: true)
        let provider = FoundationModelReasonProvider(
            isModelAvailable: { true },
            generator: { _ in "Données officielles SHOM : sors maintenant." })

        let text = await provider.reason(for: decision, conditions: Fixtures.conditions())

        XCTAssertEqual(text, decision.reason, "officiality claims never replace the template")
        XCTAssertFalse(
            FoundationModelReasonProvider.isAcceptable(
                "Données officielles SHOM : sors maintenant.",
                for: decision,
                conditions: Fixtures.conditions()))
    }

    func testInventedNumberFallsBackToTheTemplate() async {
        let decision = Fixtures.decision(activity: .shoreFishing, go: false, blockers: [.wind])
        let provider = FoundationModelReasonProvider(
            isModelAvailable: { true },
            generator: { _ in "Vent 42 km/h, reste à terre." })

        let text = await provider.reason(for: decision, conditions: Fixtures.conditions())

        XCTAssertEqual(text, decision.reason, "an invented digit hands back to the template")
        XCTAssertFalse(
            FoundationModelReasonProvider.isAcceptable(
                "Vent 42 km/h, reste à terre.",
                for: decision,
                conditions: Fixtures.conditions()))
    }

    func testUnavailableModelFallsBackToTheTemplate() async {
        let provider = FoundationModelReasonProvider(
            isModelAvailable: { false },
            generator: { _ in "Reste à terre, le vent est trop fort." })
        let decision = Fixtures.decision(activity: .walking, go: false, blockers: [.wind])

        let text = await provider.reason(for: decision, conditions: Fixtures.conditions())

        XCTAssertEqual(text, decision.reason, "unavailable model never reaches the generator")
        XCTAssertFalse(text.isEmpty)
    }

    func testNilGenerationFallsBackToTheTemplate() async {
        let provider = FoundationModelReasonProvider(
            isModelAvailable: { true },
            generator: { _ in nil })
        let decision = Fixtures.decision(activity: .boating, go: true)

        let text = await provider.reason(for: decision, conditions: Fixtures.conditions())

        XCTAssertEqual(text, decision.reason)
        XCTAssertFalse(text.isEmpty)
    }

    func testAcceptableConstrainedSentenceReplacesTheTemplate() async {
        let provider = FoundationModelReasonProvider(
            isModelAvailable: { true },
            generator: { _ in "Reste à terre, le vent est trop fort." })
        let decision = Fixtures.decision(activity: .walking, go: false, blockers: [.wind])

        let text = await provider.reason(for: decision, conditions: Fixtures.conditions())

        XCTAssertEqual(text, "Reste à terre, le vent est trop fort.")
    }

    func testPrewarmIsSafeWithoutRequiringAppleIntelligence() {
        // Must not throw or hang: no-op when unavailable, session reuse when ready.
        FoundationModelReasonProvider.prewarm()
        FoundationModelReasonProvider.prewarm()
        _ = FoundationModelReasonProvider.isSystemModelAvailable()
    }
}

private actor CallCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}

/// Local fixtures so this suite stays independent of `ReasonProviderTests`.
private enum Fixtures {
    static let at: Date = {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = .gmt
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return parser.date(from: "2026-10-28T09:00") ?? .distantPast
    }()

    static func decision(
        activity: Activity,
        go: Bool = true,
        blockers: [ActivityBlocker] = [],
        reason: String? = nil) -> GoDecision
    {
        GoDecision(
            activity: activity,
            spot: SpotCatalog.arcachonEyrac,
            go: go,
            score: go ? 0.82 : 0.18,
            reason: reason ?? DecisionReason.text(activity: activity, go: go, blockers: blockers),
            reasonSource: .template,
            nextGoodWindow: nil,
            computedAt: at,
            blockers: blockers)
    }

    static func conditions(water: Double? = 17) -> Conditions {
        Conditions(
            spot: SpotCatalog.arcachonEyrac,
            at: at,
            tide: TideState(
                current: TideEvent(
                    time: at.addingTimeInterval(-3600),
                    kind: .low,
                    height: 0.88),
                next: TideEvent(
                    time: at.addingTimeInterval(3 * 3600),
                    kind: .high,
                    height: 4.2),
                coefficient: 85,
                curve: [TidePoint(time: at.addingTimeInterval(-3600), height: 0.88)]),
            weather: WeatherNow(
                temperature: 16,
                condition: .partlyCloudy,
                precipitationChance: 0.1,
                cloudCover: 0.4,
                wind: Wind(speed: 12, gust: 20, directionDegrees: 250),
                visibility: 20000),
            swell: Swell(
                waveHeight: 1.2,
                period: 9,
                directionDegrees: 280,
                seaSurfaceTemperature: water,
                source: .model))
    }
}
