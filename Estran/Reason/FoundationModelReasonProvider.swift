import EstranCore
import Foundation

#if canImport(FoundationModels)
    import FoundationModels
#endif

/// On-device sentence generator, with the deterministic template as its floor.
///
/// The model is optional by design. When Apple Intelligence is missing, the
/// model is not ready, generation errors, or generation runs past `timeout`,
/// the provider returns `decision.reason` unchanged: the decision never waits
/// on the model and no surface is left blank.
///
/// Generation uses constrained decoding (`ReasonDraft` via
/// `session.respond(to:generating:)`). A generated sentence is shown only when
/// it passes `isAcceptable`, which rejects an invented number, a « Oui » where
/// the product forbids it, a claim of officiality, or an emoji. Swimming never
/// reaches the model: the template alone phrases the risk level (invariant 1).
/// The template is the safety net, not a visible downgrade
/// (`ARCHITECTURE_PLAN.md` §10.1).
struct FoundationModelReasonProvider: ReasonTextProviding {
    /// Produces a candidate sentence from a prompt. `nil` means "no text".
    typealias Generator = @Sendable (_ prompt: String) async -> String?

    /// Longest a caller waits for the model before the template is used.
    static let defaultTimeout: Duration = .seconds(2)

    /// Upper bound on an accepted sentence, in characters.
    static let maximumCharacters = 160

    /// Upper bound on an accepted sentence, in words. The prompt asks for 12;
    /// the slack absorbs French elisions without letting a paragraph through.
    static let maximumWords = 20

    private let fallback: any ReasonTextProviding
    private let timeout: Duration
    private let isModelAvailable: @Sendable () -> Bool
    private let generator: Generator

    /// - Parameters:
    ///   - fallback: used on unavailability, timeout, error or rejection.
    ///   - timeout: hard cap on generation; the decision never waits longer.
    ///   - isModelAvailable: injectable so the fallback path is testable
    ///     without an eligible device.
    ///   - generator: injectable for the same reason; defaults to the on-device
    ///     model with `@Generable` constrained decoding.
    init(
        fallback: any ReasonTextProviding = TemplateReasonProvider(),
        timeout: Duration = FoundationModelReasonProvider.defaultTimeout,
        isModelAvailable: @escaping @Sendable () -> Bool = {
            FoundationModelReasonProvider.isSystemModelAvailable()
        },
        generator: @escaping Generator = { prompt in
            await FoundationModelReasonProvider.generate(prompt: prompt)
        })
    {
        self.fallback = fallback
        self.timeout = timeout
        self.isModelAvailable = isModelAvailable
        self.generator = generator
    }

    func reason(for decision: GoDecision, conditions: Conditions) async -> String {
        // Invariant 1: swimming is a risk level, never a model-phrased Oui/Non.
        if decision.activity == .swimming {
            return await fallback.reason(for: decision, conditions: conditions)
        }

        // Cheap gate first: no session and no prompt on a device that cannot
        // answer. The template is already a complete sentence.
        guard isModelAvailable() else {
            return await fallback.reason(for: decision, conditions: conditions)
        }

        let prompt = Self.prompt(for: decision, conditions: conditions)
        let candidate = await runWithTimeout(timeout) { await generator(prompt) }

        guard let text = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
              Self.isAcceptable(text, for: decision, conditions: conditions)
        else {
            return await fallback.reason(for: decision, conditions: conditions)
        }
        return text
    }

    // MARK: - Model

    /// `true` when the on-device model can answer on this device.
    ///
    /// Availability is an implementation detail: it is never surfaced in the
    /// UI, and a `false` here is not an error state.
    static func isSystemModelAvailable() -> Bool {
        #if canImport(FoundationModels)
            SystemLanguageModel.default.availability == .available
        #else
            false
        #endif
    }

    /// Loads the on-device session early when the app knows a reason will be asked.
    ///
    /// No-op when Apple Intelligence is unavailable. Call from Home (or the
    /// spot detail) once conditions are known; generation reuses the same
    /// session so the prewarm pays off (`LanguageModelSession.prewarm`, iOS 26+).
    static func prewarm() {
        #if canImport(FoundationModels)
            ReasonSessionStore.prewarmIfPossible()
        #endif
    }

    /// One constrained generation from the on-device model, or `nil` on failure.
    static func generate(prompt: String) async -> String? {
        #if canImport(FoundationModels)
            guard SystemLanguageModel.default.availability == .available else {
                return nil
            }
            let session = ReasonSessionStore.session()
            do {
                let response = try await session.respond(
                    to: prompt,
                    generating: ReasonDraft.self,
                    options: GenerationOptions(temperature: 0.3, maximumResponseTokens: 80))
                return response.content.sentence
            } catch {
                // Guardrail refusal, context overflow, cancellation: the template
                // answers. Nothing is logged as a user-visible failure.
                return nil
            }
        #else
            return nil
        #endif
    }

    /// System instructions: the same voice as the prompt, kept short.
    static let instructions = """
    Tu écris des phrases courtes, factuelles et tutoyantes en français pour \
    une app de conditions côtières. Tu n'inventes aucune donnée.
    """

    // MARK: - Timeout

    /// Runs `work` and stops waiting after `timeout`.
    ///
    /// The work task is cancelled but never awaited: a model that ignores
    /// cancellation must not hold a decision that is already displayable. The
    /// first result wins and the continuation resumes exactly once.
    private func runWithTimeout(
        _ timeout: Duration,
        work: @escaping @Sendable () async -> String?) async -> String?
    {
        let gate = ReasonResumeGate()
        return await withCheckedContinuation { continuation in
            let workTask = Task {
                let value = await work()
                if gate.claim() {
                    continuation.resume(returning: value)
                }
            }
            Task {
                try? await Task.sleep(for: timeout)
                if gate.claim() {
                    workTask.cancel()
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Prompt

    /// The French prompt handed to the model.
    ///
    /// Pure and static so the copy, the facts it carries and the constraints it
    /// states are testable without an eligible device. It carries only values
    /// the decision or the conditions actually hold: a missing water
    /// temperature says « non mesurée », it never becomes a neutral number.
    static func prompt(for decision: GoDecision, conditions: Conditions) -> String {
        var lines: [String] = [
            "Tu écris la phrase de raison affichée par Estran, une app de sorties",
            "au bord du bassin d'Arcachon et du Médoc.",
            "",
            "Contexte",
            "- Spot : \(conditions.spot.name)",
            "- Activité : \(decision.activity.displayNameWithArticle)",
            "- Verdict : \(verdict(for: decision))",
            "- Points bloquants : \(blockerLine(for: decision.blockers))"
        ]
        if let tide = tideLine(for: conditions) {
            lines.append("- \(tide)")
        }
        lines.append("- Vent : \(rounded(conditions.weather.wind.speed)) km/h")
        lines.append("- \(swellLine(for: conditions.swell))")
        if let water = conditions.swell.seaSurfaceTemperature {
            lines.append("- Eau : \(rounded(water)) °C")
        } else {
            lines.append("- Eau : non mesurée")
        }
        lines.append("")
        lines.append("Consignes")
        lines.append(contentsOf: rules(for: decision).map { "- \($0)" })
        lines.append("")
        lines.append("Réponds uniquement par la phrase.")
        return lines.joined(separator: "\n")
    }

    /// Constraints, including the ones that depend on the activity.
    private static func rules(for decision: GoDecision) -> [String] {
        var rules = [
            "Une seule phrase, 12 mots maximum.",
            "Tutoiement, ton direct et factuel.",
            "Pas de salutation, pas de formule d'IA, pas d'emoji, pas d'exclamation.",
            "N'invente aucun chiffre ni aucune donnée absente du contexte.",
            "Ne dis jamais que la donnée est officielle ni mesurée sur place."
        ]
        if decision.activity == .swimming {
            rules.append(
                "N'écris jamais « Oui » : la baignade s'exprime par un niveau de risque.")
            rules.append(
                "Ne rassure pas : les baïnes et les courants restent dangereux toute l'année.")
        } else if !decision.go {
            rules.append("N'écris jamais « Oui » ni « c'est bon » : le verdict est défavorable.")
        }
        return rules
    }

    /// The verdict in words.
    ///
    /// Swimming has no `Oui`: its verdict is the risk level, so the model is
    /// never handed a yes/no to phrase (invariant 1).
    static func verdict(for decision: GoDecision) -> String {
        if decision.activity == .swimming {
            return SwimmingRiskLevel(decision: decision).title.lowercased()
        }
        return decision.go ? "favorable" : "défavorable"
    }

    /// « Vent trop fort, Pas à marée basse » gives the model the reasons the
    /// engine already found, so it explains the verdict instead of guessing it.
    static func blockerLine(for blockers: [ActivityBlocker]) -> String {
        guard !blockers.isEmpty else { return "aucun" }
        return blockers.map(\.shortLabel).joined(separator: ", ")
    }

    /// « Marée : basse à 14h20 (hauteur 0,88 m) », or `nil` without an event.
    private static func tideLine(for conditions: Conditions) -> String? {
        guard let event = tideEvent(for: conditions) else { return nil }
        let kind = event.kind == .low ? "basse" : "haute"
        let time = clockTime(event.time, in: conditions.spot.timezone)
        return "Marée : \(kind) à \(time) (hauteur \(decimal(event.height, digits: 2)) m)"
    }

    /// The tide event closest to the conditions instant, or `nil`.
    static func tideEvent(for conditions: Conditions) -> TideEvent? {
        let candidates = [conditions.tide.current, conditions.tide.next].compactMap(\.self)
        return candidates.min(by: {
            abs($0.time.timeIntervalSince(conditions.at))
                < abs($1.time.timeIntervalSince(conditions.at))
        })
    }

    /// « Houle : 1,2 m, modèle » or « Houle : 0,4 m, estimation issue du vent ».
    ///
    /// An estimated sea says it is computed from the wind: the model must never
    /// present it as a measurement.
    private static func swellLine(for swell: Swell) -> String {
        let source = swell.isEstimated ? "estimation issue du vent" : "modèle"
        return "Houle : \(decimal(swell.waveHeight, digits: 1)) m, \(source)"
    }

    // MARK: - Formatting

    static func rounded(_ value: Double) -> Int {
        Int(value.rounded())
    }

    /// French decimal comma, as elsewhere in the UI.
    static func decimal(_ value: Double, digits: Int) -> String {
        String(format: "%.\(digits)f", value)
            .replacingOccurrences(of: ".", with: ",")
    }

    /// « 14h20 », in the spot's zone: a tide time is local, never the device's.
    static func clockTime(_ date: Date, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH'h'mm"
        return formatter.string(from: date)
    }
}
