@testable import Estran
import EstranCore
import XCTest

/// M4 — the on-device reason provider wired to the answer card.
///
/// The provider is the seam, so every test injects one: nothing here needs an
/// eligible device or a live model. What is asserted is the wiring — the card
/// shows the template until a sentence exists, the sentence describes the
/// decision on screen, and VoiceOver reads the same line the card draws
/// (VoiceOver audit F1).
@MainActor
final class ReasonIntegrationTests: XCTestCase {
    // MARK: - The model answers

    func testRefinedSentenceIsDisplayedOnceTheProviderAnswers() async throws {
        let sentence = "Le vent tombe, le banc reste découvert."
        let app = makeApp(reasonProvider: FixedReasonProvider(sentence: sentence))

        await app.reload()
        try await waitForRefinement(app)

        XCTAssertEqual(app.refinedReason, sentence)
        let decision = try XCTUnwrap(app.decision)
        let conditions = try XCTUnwrap(app.store.conditions)
        let card = AnswerCard(
            decision: decision,
            activity: decision.activity,
            conditions: conditions,
            refinedReason: app.refinedReason)
        XCTAssertEqual(
            card.displayedReason, sentence,
            "the card draws the generated sentence, not the template")
    }

    func testTemplateStaysVisibleWhileTheProviderHasNotAnswered() async throws {
        let gate = ReasonGate()
        let app = makeApp(
            reasonProvider: ScriptedReasonProvider(
                sentences: ["Phrase pour la pêche."],
                gate: gate))

        await app.reload()
        await gate.waitUntilStarted()

        XCTAssertNil(
            app.refinedReason,
            "no sentence yet: the card keeps the template, never a spinner or a placeholder")

        await gate.open()
        try await waitForRefinement(app)
        XCTAssertEqual(app.refinedReason, "Phrase pour la pêche.")
    }

    // MARK: - Stale-answer guard

    func testLateAnswerForAPreviousActivityIsDiscarded() async throws {
        let gate = ReasonGate()
        // First call: the fishing answer, released by the test after the switch.
        // Second call: the walking answer, returned immediately.
        let provider = ScriptedReasonProvider(
            sentences: ["Phrase pour la pêche.", "Phrase pour la balade."],
            gate: gate)
        let app = makeApp(reasonProvider: provider)

        await app.reload()
        XCTAssertEqual(app.activity, .shoreFishing)
        await gate.waitUntilStarted()

        app.select(activity: .walking)
        try await waitForRefinement(app)
        XCTAssertEqual(app.refinedReason, "Phrase pour la balade.")

        // The fishing sentence arrives now, for a decision that is off screen.
        await gate.open()
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(
            app.refinedReason, "Phrase pour la balade.",
            "a late answer for the previous activity must never overwrite the current one")
        XCTAssertEqual(app.decision?.activity, .walking)
    }

    // MARK: - The template path

    func testTemplateProviderLeavesTheSentenceTheCardShows() async throws {
        let app = makeApp(reasonProvider: TemplateReasonProvider())

        await app.reload()
        try await waitForRefinement(app)

        let decision = try XCTUnwrap(app.decision)
        let conditions = try XCTUnwrap(app.store.conditions)
        let card = AnswerCard(
            decision: decision,
            activity: decision.activity,
            conditions: conditions,
            refinedReason: app.refinedReason)

        XCTAssertEqual(app.refinedReason, decision.reason, "the template is the floor")
        XCTAssertEqual(card.displayedReason, app.refinedReason)
        XCTAssertFalse(try XCTUnwrap(app.refinedReason).isEmpty, "never an empty sentence")
    }

    func testCardFallsBackToTheTemplateWithoutAValidSentence() {
        let decision = IntegrationFixtures.decision(activity: .walking, go: true)
        let conditions = IntegrationFixtures.conditions()

        let withoutSentence = AnswerCard(
            decision: decision,
            activity: .walking,
            conditions: conditions,
            refinedReason: nil)
        XCTAssertEqual(withoutSentence.displayedReason, decision.reason)

        let blankSentence = AnswerCard(
            decision: decision,
            activity: .walking,
            conditions: conditions,
            refinedReason: "   ")
        XCTAssertEqual(
            blankSentence.displayedReason, decision.reason,
            "a blank answer never blanks the card")
    }

    // MARK: - Invariant 1

    func testSwimmingDecisionNeverGetsASentenceWithOui() async throws {
        // A generator that offers the water: the provider's validation rejects
        // it, and the wiring must then show the risk sentence, never « Oui ».
        let app = makeApp(
            reasonProvider: FoundationModelReasonProvider(
                isModelAvailable: { true },
                generator: { _ in "Oui, tu peux te baigner." }))

        await app.reload()
        app.select(activity: .swimming)
        try await waitForRefinement(app)

        let decision = try XCTUnwrap(app.decision)
        let conditions = try XCTUnwrap(app.store.conditions)
        let card = AnswerCard(
            decision: decision,
            activity: .swimming,
            conditions: conditions,
            refinedReason: app.refinedReason)

        XCTAssertEqual(decision.activity, .swimming)
        XCTAssertFalse(containsOui(card.displayedReason), "invariant 1: no « Oui » for swimming")
        XCTAssertEqual(card.displayedReason, decision.reason)
    }

    // MARK: - Helpers

    private func makeApp(reasonProvider: any ReasonTextProviding) -> AppModel {
        AppModel(
            provider: FixedConditionsProvider(),
            // No App Group in tests: the stored selection must not leak in.
            selectionStorage: SpotSelectionStorage(defaults: nil),
            reasonProvider: reasonProvider)
    }

    /// Waits for the generation started by `refreshDecision` to land.
    ///
    /// The task itself is not exposed: the app may drop it at any time, so the
    /// test only waits on the observable outcome.
    private func waitForRefinement(
        _ app: AppModel,
        timeout: Duration = .seconds(5)) async throws
    {
        let deadline = ContinuousClock.now + timeout
        while app.refinedReason == nil, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNotNil(app.refinedReason, "the provider answered but nothing was displayed")
    }

    private func containsOui(_ sentence: String) -> Bool {
        sentence.range(of: "\\boui\\b", options: [.regularExpression, .caseInsensitive]) != nil
    }
}

// MARK: - Test doubles

/// One sentence, returned immediately: the happy path without a model.
private struct FixedReasonProvider: ReasonTextProviding {
    let sentence: String

    func reason(for _: GoDecision, conditions _: Conditions) async -> String {
        sentence
    }
}

/// Returns `sentences[i]` for the i-th call, and can hold the first call until
/// the test releases it — that is how a late answer is reproduced without a
/// real latency.
private actor ScriptedReasonProvider: ReasonTextProviding {
    private let sentences: [String]
    private let gate: ReasonGate?
    private var calls = 0

    init(sentences: [String], gate: ReasonGate? = nil) {
        self.sentences = sentences
        self.gate = gate
    }

    func reason(for _: GoDecision, conditions _: Conditions) async -> String {
        let index = calls
        calls += 1
        if index == 0, let gate {
            await gate.arriveAndWait()
        }
        return sentences[min(index, sentences.count - 1)]
    }
}

/// A one-shot rendezvous between the provider and the test.
private actor ReasonGate {
    private var hasStarted = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var release: CheckedContinuation<Void, Never>?
    private var isOpen = false

    /// Signals that the call is in flight, then waits for `open()`.
    func arriveAndWait() async {
        hasStarted = true
        for waiter in startWaiters {
            waiter.resume()
        }
        startWaiters.removeAll()
        guard !isOpen else { return }
        await withCheckedContinuation { release = $0 }
    }

    func waitUntilStarted() async {
        guard !hasStarted else { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func open() {
        isOpen = true
        release?.resume()
        release = nil
    }
}

/// Deterministic conditions, so a decision never depends on the clock or on a
/// network source.
private struct FixedConditionsProvider: ConditionsProviding {
    let isSampleData = true

    func conditions(for _: Spot, at _: Date) async throws -> Conditions {
        IntegrationFixtures.conditions()
    }

    func forecast(for _: Spot, from _: Date, hours: Int) async throws -> [Conditions] {
        let start = IntegrationFixtures.at
        return (0 ..< max(hours, 1)).map { hour in
            IntegrationFixtures.conditions(at: start.addingTimeInterval(Double(hour) * 3600))
        }
    }
}

/// Shared decisions and conditions, fixed in time.
private enum IntegrationFixtures {
    /// Fixed instant, so the formatted tide time never depends on the clock.
    static let at: Date = {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = .gmt
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return parser.date(from: "2026-10-28T09:00") ?? .distantPast
    }()

    static func decision(activity: Activity, go: Bool) -> GoDecision {
        GoDecision(
            activity: activity,
            spot: SpotCatalog.arcachonEyrac,
            go: go,
            score: go ? 0.82 : 0.18,
            reason: DecisionReason.text(activity: activity, go: go, blockers: []),
            reasonSource: .template,
            nextGoodWindow: nil,
            computedAt: at,
            blockers: [])
    }

    static func conditions(at instant: Date = at) -> Conditions {
        Conditions(
            spot: SpotCatalog.arcachonEyrac,
            at: instant,
            tide: TideState(
                current: TideEvent(
                    time: instant.addingTimeInterval(-3600),
                    kind: .low,
                    height: 0.88),
                next: TideEvent(
                    time: instant.addingTimeInterval(3 * 3600),
                    kind: .high,
                    height: 4.2),
                coefficient: 85,
                curve: [TidePoint(time: instant.addingTimeInterval(-3600), height: 0.88)]),
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
                seaSurfaceTemperature: 17,
                source: .model))
    }
}
