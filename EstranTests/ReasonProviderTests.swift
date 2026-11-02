@testable import Estran
import EstranCore
import XCTest

/// Compact form of the provider's validation, so each case stays one assertion.
private func isAcceptable(
    _ text: String,
    for decision: GoDecision,
    conditions: Conditions = ReasonFixtures.conditions()) -> Bool
{
    FoundationModelReasonProvider.isAcceptable(text, for: decision, conditions: conditions)
}

/// M4 — the reason sentence behind `ReasonTextProviding`.
///
/// These tests cover the part that has no model in it: the deterministic
/// template, the prompt built from the decision, the output validation, and the
/// fallback that every failure path must end on. They never require an eligible
/// device, so they pass on the simulator.
final class ReasonProviderTests: XCTestCase {
    // MARK: - Template provider

    func testTemplateProviderReturnsTheDecisionSentenceVerbatim() async {
        let decision = ReasonFixtures.decision(
            activity: .shoreFishing,
            go: false,
            blockers: [.wind],
            reason: "Vent trop fort.")

        let text = await TemplateReasonProvider().reason(
            for: decision,
            conditions: ReasonFixtures.conditions())

        XCTAssertEqual(text, "Vent trop fort.", "the fallback is the engine's sentence, byte for byte")
        XCTAssertEqual(text, decision.reason)
    }

    func testTemplateProviderNeverReturnsAnEmptySentenceForAnyActivity() async {
        let provider = TemplateReasonProvider()

        for activity in Activity.allCases {
            for go in [true, false] {
                let blockers: [ActivityBlocker] = go ? [] : [.wind]
                let decision = ReasonFixtures.decision(activity: activity, go: go, blockers: blockers)
                let text = await provider.reason(for: decision, conditions: ReasonFixtures.conditions())

                XCTAssertFalse(text.isEmpty, "\(activity.rawValue) go=\(go) produced no sentence")
                XCTAssertEqual(text, decision.reason)
            }
        }
    }

    // MARK: - Fallbacks

    func testUnavailableModelFallsBackToTheTemplate() async {
        let provider = FoundationModelReasonProvider(
            isModelAvailable: { false },
            generator: { _ in "Reste à la maison aujourd'hui." })
        let decision = ReasonFixtures.decision(activity: .shoreFishing, go: false, blockers: [.rain])

        let text = await provider.reason(for: decision, conditions: ReasonFixtures.conditions())

        XCTAssertEqual(text, decision.reason, "an unavailable model never reaches the generator")
    }

    func testEmptyGenerationFallsBackToTheTemplate() async {
        let provider = FoundationModelReasonProvider(
            isModelAvailable: { true },
            generator: { _ in "   " })
        let decision = ReasonFixtures.decision(activity: .walking, go: true)

        let text = await provider.reason(for: decision, conditions: ReasonFixtures.conditions())

        XCTAssertEqual(text, decision.reason)
    }

    func testTimeoutFallsBackToTheTemplateWithoutWaitingForTheModel() async {
        // The generator takes 2 s; the provider must answer in about 100 ms.
        let provider = FoundationModelReasonProvider(
            timeout: .milliseconds(100),
            isModelAvailable: { true },
            generator: { _ in
                try? await Task.sleep(for: .seconds(2))
                return "Reste à terre, le vent est trop fort."
            })
        let decision = ReasonFixtures.decision(activity: .walking, go: false, blockers: [.wind])

        let started = Date()
        let text = await provider.reason(for: decision, conditions: ReasonFixtures.conditions())
        let elapsed = Date().timeIntervalSince(started)

        XCTAssertEqual(text, decision.reason, "a slow model hands back to the template")
        XCTAssertLessThan(elapsed, 1, "the decision never waits on the model")
    }

    func testAcceptableGeneratedSentenceReplacesTheTemplate() async {
        let provider = FoundationModelReasonProvider(
            isModelAvailable: { true },
            generator: { _ in "Reste à terre, le vent est trop fort." })
        let decision = ReasonFixtures.decision(activity: .walking, go: false, blockers: [.wind])

        let text = await provider.reason(for: decision, conditions: ReasonFixtures.conditions())

        XCTAssertEqual(text, "Reste à terre, le vent est trop fort.")
    }

    func testGeneratedReasonIsNeverEmptyForEveryActivity() async {
        let providers: [any ReasonTextProviding] = [
            TemplateReasonProvider(),
            FoundationModelReasonProvider(isModelAvailable: { false }),
            FoundationModelReasonProvider(isModelAvailable: { true }, generator: { _ in "" })
        ]

        for activity in Activity.allCases {
            for go in [true, false] {
                let decision = ReasonFixtures.decision(
                    activity: activity,
                    go: go,
                    blockers: go ? [] : [.dataUnavailable])
                for provider in providers {
                    let text = await provider.reason(
                        for: decision,
                        conditions: ReasonFixtures.conditions())
                    XCTAssertFalse(
                        text.isEmpty,
                        "\(type(of: provider)) returned nothing for \(activity.rawValue) go=\(go)")
                }
            }
        }
    }

    // MARK: - Output validation

    func testNumberIsComparedAsAValueNotASubstring() {
        let decision = ReasonFixtures.decision(activity: .shoreFishing, go: false, blockers: [.wind])

        XCTAssertFalse(
            isAcceptable("Marée basse à 03h40, vent 42 km/h.", for: decision),
            "an invented value is rejected, never shown")
        XCTAssertFalse(
            isAcceptable("Vent 2 km/h, reste à terre.", for: decision),
            "« 2 » must not pass because the prompt carries « 1,2 m »")
        XCTAssertFalse(
            isAcceptable("Houle 0,1 m, reste à terre.", for: decision),
            "an invented decimal is rejected")
        XCTAssertTrue(
            isAcceptable("Vent 12 km/h : reste à terre.", for: decision),
            "a value the prompt carries is allowed")
        XCTAssertTrue(
            isAcceptable("Houle 1,2 m, reste à terre.", for: decision),
            "the exact decimal the prompt carries is allowed")
    }

    func testInventedNumberHidingInsideARealValueIsRejected() {
        // Set comparison, not substring: « 2 » is not in the prompt, even
        // though the prompt carries « 1,2 m ».
        let decision = ReasonFixtures.decision(activity: .swimming, go: true)

        XCTAssertFalse(
            isAcceptable("Vent 2 km/h, reste prudent.", for: decision),
            "« 2 » must not pass because « 1,2 m » exists")
        XCTAssertFalse(
            isAcceptable("Houle 0,1 m, reste prudent.", for: decision),
            "an invented decimal is rejected")
        XCTAssertTrue(
            isAcceptable("Houle 1,2 m, reste prudent.", for: decision),
            "the exact value the prompt carries is allowed")
    }

    func testGeneratedOuiForSwimmingIsRejected() {
        let decision = ReasonFixtures.decision(activity: .swimming, go: true)

        XCTAssertFalse(
            isAcceptable("Oui, tu peux te baigner.", for: decision),
            "invariant 1: no Oui for swimming, generated text included")
        XCTAssertFalse(isAcceptable("Aujourd'hui, oui.", for: decision))
        XCTAssertTrue(isAcceptable("Courants faibles, reste dans une zone surveillée.", for: decision))
    }

    func testForbiddenSwimmingReassuranceIsRejected() {
        // Safety rule: swimming is a risk level, never an invitation.
        let decision = ReasonFixtures.decision(activity: .swimming, go: true)
        let forbidden = [
            "Tu peux te baigner.", "Baignade agréable aujourd'hui.",
            "On peut se baigner ce matin.", "Tu pourras te baigner.",
            "Profite de la mer.", "C'est bon, vas-y.", "Oui, c'est bon."
        ]

        for sentence in forbidden {
            XCTAssertFalse(
                isAcceptable(sentence, for: decision),
                "swimming must never invite the swimmer: « \(sentence) »")
        }
        XCTAssertTrue(
            isAcceptable("Courants de marée modérés, reste prudent.", for: decision),
            "a risk statement is the accepted form")
    }

    func testGeneratedOuiForANonVerdictIsRejected() {
        let decision = ReasonFixtures.decision(activity: .boating, go: false, blockers: [.wind])

        XCTAssertFalse(isAcceptable("Oui, sors en bateau.", for: decision))
        XCTAssertFalse(isAcceptable("C'est bon, le vent est faible.", for: decision))
    }

    func testGeneratedOfficialityClaimAndEmojiAreRejected() {
        let decision = ReasonFixtures.decision(activity: .walking, go: true)

        XCTAssertFalse(
            isAcceptable("Données officielles SHOM : sors maintenant.", for: decision),
            "invariant 2: generated text never claims officiality")
        XCTAssertFalse(isAcceptable("Belle balade en vue 🌊", for: decision))
        XCTAssertFalse(isAcceptable("", for: decision))
    }

    func testRejectedGeneratedSentencesFallBackToTheTemplateReason() async {
        // Any rejection returns decision.reason: the template is the floor.
        let decision = ReasonFixtures.decision(activity: .swimming, go: true)

        for sentence in ["Tu peux te baigner.", "Vent 2 km/h, reste prudent."] {
            let provider = FoundationModelReasonProvider(
                isModelAvailable: { true },
                generator: { _ in sentence })
            let text = await provider.reason(for: decision, conditions: ReasonFixtures.conditions())

            XCTAssertEqual(
                text,
                decision.reason,
                "« \(sentence) » must hand back to the template")
        }
    }

    // MARK: - Runtime probes

    func testDefaultProviderAnswersThroughTheModelOrTheTemplate() async {
        // End-to-end smoke: on a runtime where Apple Intelligence is available
        // this really calls the on-device model; elsewhere it exercises the
        // fallback. Only the contract is asserted: one non-empty sentence.
        let decision = ReasonFixtures.decision(activity: .walking, go: true)

        let text = await FoundationModelReasonProvider().reason(
            for: decision,
            conditions: ReasonFixtures.conditions())

        XCTAssertFalse(text.isEmpty)
        print("Default provider sentence: \(text)")
    }

    func testModelAvailabilityCheckIsSafeOnEveryRuntime() {
        let first = FoundationModelReasonProvider.isSystemModelAvailable()
        let second = FoundationModelReasonProvider.isSystemModelAvailable()

        XCTAssertEqual(first, second, "availability is stable within a run")
        print("FoundationModels availability in this runtime: \(first)")
    }
}

/// The French prompt: what the model is told, and what it must not say.
final class ReasonPromptTests: XCTestCase {
    func testPromptNamesTheActivityTheVerdictAndTheBlockers() {
        let decision = ReasonFixtures.decision(
            activity: .shoreFishing,
            go: false,
            blockers: [.wind, .tideTiming])

        let prompt = FoundationModelReasonProvider.prompt(
            for: decision,
            conditions: ReasonFixtures.conditions())

        XCTAssertTrue(prompt.contains("la pêche à pied"), "the activity is named in French")
        XCTAssertTrue(prompt.contains("Verdict : défavorable"))
        XCTAssertTrue(prompt.contains("Vent trop fort"), "the first blocker reaches the prompt")
        XCTAssertTrue(prompt.contains("Pas à marée basse"), "every blocker reaches the prompt")
    }

    func testSwimmingPromptForbidsOui() {
        let decision = ReasonFixtures.decision(activity: .swimming, go: true)

        let prompt = FoundationModelReasonProvider.prompt(
            for: decision,
            conditions: ReasonFixtures.conditions())

        XCTAssertTrue(prompt.contains("la baignade"))
        XCTAssertTrue(prompt.contains("N'écris jamais « Oui »"))
        XCTAssertTrue(prompt.contains("niveau de risque"))
        XCTAssertFalse(
            prompt.contains("Verdict : favorable"),
            "swimming is never handed a yes/no verdict to phrase")
    }

    func testPromptForANonVerdictForbidsOui() {
        let decision = ReasonFixtures.decision(activity: .surfing, go: false, blockers: [.waveTooLarge])

        let prompt = FoundationModelReasonProvider.prompt(
            for: decision,
            conditions: ReasonFixtures.conditions())

        XCTAssertTrue(prompt.contains("Verdict : défavorable"))
        XCTAssertTrue(prompt.contains("N'écris jamais « Oui »"))
    }

    func testPromptCarriesTheTideWindSwellAndWaterTemperature() {
        let prompt = FoundationModelReasonProvider.prompt(
            for: ReasonFixtures.decision(activity: .walking),
            conditions: ReasonFixtures.conditions())

        XCTAssertTrue(prompt.contains("Marée : basse à"), "the tide event is described")
        XCTAssertTrue(prompt.contains("hauteur 0,88 m"), "the tide height uses the French comma")
        XCTAssertTrue(prompt.contains("Vent : 12 km/h"))
        XCTAssertTrue(prompt.contains("Houle : 1,2 m"))
        XCTAssertTrue(prompt.contains("Eau : 17 °C"))
        XCTAssertTrue(prompt.contains("Points bloquants : aucun"))
    }

    func testPromptSaysTheWaterIsNotMeasuredInsteadOfGuessing() {
        let prompt = FoundationModelReasonProvider.prompt(
            for: ReasonFixtures.decision(activity: .swimming),
            conditions: ReasonFixtures.conditions(water: nil))

        XCTAssertTrue(prompt.contains("Eau : non mesurée"), "a missing value is stated, never filled")
        XCTAssertFalse(prompt.contains("Eau : 0 °C"), "a missing temperature is never 0 °C")
    }

    func testPromptLabelsAnEstimatedSea() {
        let prompt = FoundationModelReasonProvider.prompt(
            for: ReasonFixtures.decision(activity: .surfing),
            conditions: ReasonFixtures.conditions(source: .windSeaEstimate))

        XCTAssertTrue(prompt.contains("estimation issue du vent"))
        XCTAssertFalse(prompt.contains("Houle : 1,2 m, modèle"))
    }
}

/// Shared decisions and conditions, so both suites describe the same world.
private enum ReasonFixtures {
    /// Fixed instant, so the formatted tide time never depends on the clock.
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

    static func conditions(
        water: Double? = 17,
        source: Swell.Source = .model) -> Conditions
    {
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
                source: source))
    }
}
