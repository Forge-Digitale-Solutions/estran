import EstranCore

/// The seam between the decision engine and any text generator.
///
/// Every surface reads its sentence through this protocol, so an unavailable or
/// failing model can change the wording but never the verdict. Implementations
/// never throw and never return an empty string: the guaranteed answer is
/// `decision.reason`, the deterministic French sentence the engine already
/// built (`DecisionReason.text`).
///
/// The signature returns text only. `GoDecision` is immutable and carries the
/// `reasonSource` of the sentence it stores, so a generator cannot silently
/// rewrite a decision the app, the widget and Siri all read.
protocol ReasonTextProviding: Sendable {
    /// One short French sentence explaining `decision`.
    ///
    /// Returns `decision.reason` unchanged when no better sentence can be
    /// produced; it is never empty.
    func reason(for decision: GoDecision, conditions: Conditions) async -> String
}

/// The deterministic fallback: the engine's sentence, byte for byte.
///
/// It needs neither network, nor model, nor clock, so it is the floor every
/// other provider falls back to. It is also the provider for lists (home,
/// activity picker, widgets), where a model call per row would be wasted work.
struct TemplateReasonProvider: ReasonTextProviding {
    func reason(for decision: GoDecision, conditions _: Conditions) async -> String {
        decision.reason
    }
}
