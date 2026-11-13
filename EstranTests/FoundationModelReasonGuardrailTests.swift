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

    func testUngrammaticalPossessiveFragmentIsRejected() {
        let decision = Fixtures.decision(
            activity: .shoreFishing,
            go: false,
            blockers: [.insufficientMargin],
            reason: "Marge insuffisante.")
        let bad = "Ta marge insuffisante pour la pêche à pied à Arcachon-Eyrac."

        XCTAssertFalse(
            FoundationModelReasonProvider.isAcceptable(
                bad,
                for: decision,
                conditions: Fixtures.conditions()),
            "a possessive noun+adjective fragment without a verb must fail closed")
    }

    func testUngrammaticalPossessiveFragmentFallsBackToTheTemplate() async {
        let decision = Fixtures.decision(
            activity: .shoreFishing,
            go: false,
            blockers: [.insufficientMargin],
            reason: "Marge insuffisante.")
        let provider = FoundationModelReasonProvider(
            isModelAvailable: { true },
            generator: { _ in "Ta marge insuffisante pour la pêche à pied à Arcachon-Eyrac." })

        let text = await provider.reason(for: decision, conditions: Fixtures.conditions())

        XCTAssertEqual(text, decision.reason, "broken French never replaces the deterministic reason")
    }

    func testCompleteSentenceWithConjugatedVerbIsAcceptable() {
        let decision = Fixtures.decision(
            activity: .shoreFishing,
            go: false,
            blockers: [.insufficientMargin],
            reason: "Marge insuffisante.")
        let good = "Ta marge est trop faible pour la pêche à pied ce soir."

        XCTAssertTrue(
            FoundationModelReasonProvider.isAcceptable(
                good,
                for: decision,
                conditions: Fixtures.conditions()),
            "a short complete sentence with a conjugated verb must pass")
    }

    func testSentenceLongerThanMaximumCharactersIsRejected() {
        let decision = Fixtures.decision(activity: .walking, go: false, blockers: [.wind])
        let long = String(repeating: "Le vent est trop fort pour marcher aujourd'hui ici. ", count: 4)

        XCTAssertGreaterThan(long.count, FoundationModelReasonProvider.maximumCharacters)
        XCTAssertFalse(
            FoundationModelReasonProvider.isAcceptable(
                long,
                for: decision,
                conditions: Fixtures.conditions()))
    }

    func testPrewarmIsSafeWithoutRequiringAppleIntelligence() {
        // Must not throw or hang: no-op when unavailable, session reuse when ready.
        FoundationModelReasonProvider.prewarm()
        FoundationModelReasonProvider.prewarm()
        _ = FoundationModelReasonProvider.isSystemModelAvailable()
    }

    // MARK: - Polarity (6.9 store frame 01/08)

    /// The sentence a real run generated under a green « Oui »
    /// (`build/store/6.9/01-home-oui.png`). It must never be accepted for a
    /// favourable verdict, whatever produced it.
    static let contradictoryGoSentence =
        "La marge est trop faible pour la balade à la pointe de Grave."

    func testContradictorySentenceUnderAGoDecisionIsRejected() {
        let decision = Fixtures.decision(activity: .walking, go: true, spot: SpotCatalog.pointeDeGrave)

        XCTAssertFalse(
            FoundationModelReasonProvider.isAcceptable(
                Self.contradictoryGoSentence,
                for: decision,
                conditions: Fixtures.conditions(spot: SpotCatalog.pointeDeGrave)),
            "a reason that argues the opposite of its own verdict must fail closed")
    }

    func testContradictorySentenceNeverReplacesAGoVerdict() async {
        let callCount = CallCounter()
        let provider = FoundationModelReasonProvider(
            isModelAvailable: { true },
            generator: { _ in
                await callCount.increment()
                return Self.contradictoryGoSentence
            })
        let decision = Fixtures.decision(activity: .walking, go: true, spot: SpotCatalog.pointeDeGrave)

        let text = await provider.reason(
            for: decision,
            conditions: Fixtures.conditions(spot: SpotCatalog.pointeDeGrave))

        XCTAssertEqual(text, decision.reason, "the engine's sentence is the answer for a Oui")
        let calls = await callCount.value
        XCTAssertEqual(calls, 0, "a favourable verdict never reaches the model")
    }

    func testPositiveSentenceUnderAGoVerdictIsAccepted() {
        let decision = Fixtures.decision(activity: .walking, go: true, spot: SpotCatalog.pointeDeGrave)

        XCTAssertTrue(
            FoundationModelReasonProvider.isAcceptable(
                "C'est le bon moment pour la balade à Pointe de Grave.",
                for: decision,
                conditions: Fixtures.conditions(spot: SpotCatalog.pointeDeGrave)),
            "a sentence that agrees with the verdict must still pass")
    }

    func testPositiveSentenceUnderANoGoVerdictIsRejected() {
        let decision = Fixtures.decision(
            activity: .shoreFishing,
            go: false,
            blockers: [.wind],
            spot: SpotCatalog.pointeDeGrave)

        for sentence in [
            "C'est le bon moment pour la pêche à pied à Pointe de Grave.",
            "Le vent est idéal pour la pêche à pied.",
            "La marée est parfaite pour la pêche à pied."
        ] {
            XCTAssertFalse(
                FoundationModelReasonProvider.isAcceptable(
                    sentence,
                    for: decision,
                    conditions: Fixtures.conditions(spot: SpotCatalog.pointeDeGrave)),
                "« \(sentence) » accepts a verdict the engine refused")
        }
    }

    // MARK: - Spot names

    func testLowercasedSpotNameIsRejected() {
        let decision = Fixtures.decision(
            activity: .shoreFishing,
            go: false,
            blockers: [.insufficientMargin],
            spot: SpotCatalog.pointeDeGrave)

        XCTAssertFalse(
            FoundationModelReasonProvider.isAcceptable(
                "Ta marge est trop faible pour la pêche à pied à la pointe de Grave.",
                for: decision,
                conditions: Fixtures.conditions(spot: SpotCatalog.pointeDeGrave)),
            "« pointe de Grave » is not the catalog's « Pointe de Grave »")
        XCTAssertTrue(
            FoundationModelReasonProvider.isAcceptable(
                "Ta marge est trop faible pour la pêche à pied à Pointe de Grave.",
                for: decision,
                conditions: Fixtures.conditions(spot: SpotCatalog.pointeDeGrave)),
            "the exact catalog name passes")
    }

    func testAnotherSpotsNameIsRejected() {
        let decision = Fixtures.decision(
            activity: .boating,
            go: false,
            blockers: [.wind],
            spot: SpotCatalog.pointeDeGrave)

        XCTAssertFalse(
            FoundationModelReasonProvider.isAcceptable(
                "Le vent est trop fort pour le bateau à Arcachon-Eyrac.",
                for: decision,
                conditions: Fixtures.conditions(spot: SpotCatalog.pointeDeGrave)),
            "a sentence may not name the other spot")
    }

    func testSpotNameCasingFallsBackToTheTemplate() async {
        let provider = FoundationModelReasonProvider(
            isModelAvailable: { true },
            generator: { _ in "Ta marge est trop faible pour la pêche à pied à la pointe de Grave." })
        let decision = Fixtures.decision(
            activity: .shoreFishing,
            go: false,
            blockers: [.insufficientMargin],
            spot: SpotCatalog.pointeDeGrave)

        let text = await provider.reason(
            for: decision,
            conditions: Fixtures.conditions(spot: SpotCatalog.pointeDeGrave))

        XCTAssertEqual(text, decision.reason, "a rewritten proper name hands back to the template")
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
        reason: String? = nil,
        spot: Spot = SpotCatalog.arcachonEyrac) -> GoDecision
    {
        GoDecision(
            activity: activity,
            spot: spot,
            go: go,
            score: go ? 0.82 : 0.18,
            reason: reason ?? DecisionReason.text(activity: activity, go: go, blockers: blockers),
            reasonSource: .template,
            nextGoodWindow: nil,
            computedAt: at,
            blockers: blockers)
    }

    static func conditions(
        water: Double? = 17,
        spot: Spot = SpotCatalog.arcachonEyrac) -> Conditions
    {
        Conditions(
            spot: spot,
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
