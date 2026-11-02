import EstranCore
import Foundation

/// One activity's answer for the spot detail and the activity picker.
///
/// It bundles the decision with the windows it came from, so a row never
/// re-derives a verdict from different data than the card: both come from the
/// same `DecisionEngine` call over the same forecast.
struct ActivityOverview: Identifiable, Hashable {
    let activity: Activity
    let decision: GoDecision
    /// The good window that contains "now", when the verdict is `Oui`.
    let current: ActivitySlot?
    /// The first good window starting after "now".
    let upcoming: ActivitySlot?

    var id: String {
        activity.id
    }

    /// The data cannot answer for this activity; the row says so instead of
    /// showing a `Non` (fail closed, `AGENTS.md` invariant 4).
    var isUnavailable: Bool {
        decision.isDataUnavailable
    }
}
