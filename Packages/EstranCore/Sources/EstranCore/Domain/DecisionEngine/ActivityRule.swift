import Foundation

/// One activity's decision rule.
///
/// A rule is pure: `score` and `blockers` depend only on `Conditions`, and the
/// same inputs always produce the same outputs. `score` is bounded to `0...1`.
public protocol ActivityRule: Sendable {
    /// Activity covered by this rule.
    var activity: Activity { get }
    /// Score at or above which the answer is `Oui`, unless a blocker fires.
    var threshold: Double { get }
    /// Weighted score in `0...1`.
    func score(_ conditions: Conditions) -> Double
    /// Hard blockers that force `Non`.
    func blockers(_ conditions: Conditions) -> [ActivityBlocker]
    /// Earliest contiguous good window, scanning after the first forecast sample.
    func nextGoodWindow(from conditions: [Conditions]) -> DateInterval?
}

public extension ActivityRule {
    /// `Oui` when no blocker fires and the score reaches the threshold.
    func isGo(_ conditions: Conditions) -> Bool {
        blockers(conditions).isEmpty && score(conditions) >= threshold
    }

    /// Default window scan: the forecast is assumed to start at "now", which is
    /// the contract of the data layer. A window only contains samples that pass
    /// the full `isGo` predicate (no blocker and score at or above threshold).
    func nextGoodWindow(from conditions: [Conditions]) -> DateInterval? {
        guard let now = conditions.first?.at else { return nil }
        return WindowScanner.firstWindow(
            in: conditions,
            after: now,
            isGood: { self.isGo($0) })
    }
}
