/// Deterministic French fallback used until the Foundation Models text
/// generator takes over in M4.
///
/// The output is short, uses tutoiement-free factual phrasing, and never depends
/// on the clock or on randomness.
public enum DecisionReason {
    /// Builds the reason shown with the decision.
    public static func text(activity: Activity, go: Bool, blockers: [ActivityBlocker]) -> String {
        if go {
            return "C'est bon pour \(activity.displayNameWithArticle)."
        }
        if let blocker = blockers.first {
            return "\(blocker.shortLabel)."
        }
        return "Conditions limites pour \(activity.displayNameWithArticle)."
    }
}
