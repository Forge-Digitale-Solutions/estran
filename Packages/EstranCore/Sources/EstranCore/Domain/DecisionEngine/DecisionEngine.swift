import Foundation

/// Deterministic rule-based decision engine.
///
/// The engine owns no state and reads no clock: `decide` and `windows` are pure
/// functions of their inputs, so the app, the widgets and the Live Activity all
/// produce the same answer from the same conditions.
public struct DecisionEngine: Sendable {
    /// Rules used when no explicit rule set is injected.
    public static let defaultRules: [any ActivityRule] = [
        ShoreFishingRule(),
        SurfRule(),
        BoatingRule(),
        WalkingRule(),
        SwimmingRule()
    ]

    private let rulesByActivity: [Activity: any ActivityRule]

    public init(rules: [any ActivityRule] = DecisionEngine.defaultRules) {
        var rulesByActivity: [Activity: any ActivityRule] = [:]
        for rule in rules {
            rulesByActivity[rule.activity] = rule
        }
        self.rulesByActivity = rulesByActivity
    }

    /// Rule registered for `activity`, when any.
    public func rule(for activity: Activity) -> (any ActivityRule)? {
        rulesByActivity[activity]
    }

    /// Decision for `activity` at the instant carried by `conditions`.
    ///
    /// `forecast` is optional: pass the upcoming samples to fill
    /// `nextGoodWindow`. Without a forecast the window can only be found inside
    /// the single sample, so it stays `nil`.
    public func decide(
        activity: Activity,
        conditions: Conditions,
        forecast: [Conditions] = []) -> GoDecision
    {
        guard let rule = rulesByActivity[activity] else {
            return GoDecision(
                activity: activity,
                spot: conditions.spot,
                go: false,
                score: 0,
                reason: "Activité indisponible.",
                reasonSource: .template,
                nextGoodWindow: nil,
                computedAt: conditions.at,
                blockers: [])
        }

        let score = rule.score(conditions)
        let blockers = rule.blockers(conditions)
        let go = blockers.isEmpty && score >= rule.threshold
        let nextWindow: DateInterval?
        if go {
            nextWindow = nil
        } else {
            var horizon = forecast.isEmpty ? [conditions] : forecast
            if horizon.first?.at != conditions.at {
                horizon.insert(conditions, at: 0)
            }
            nextWindow = rule.nextGoodWindow(from: horizon)
        }

        return GoDecision(
            activity: activity,
            spot: conditions.spot,
            go: go,
            score: score,
            reason: DecisionReason.text(activity: activity, go: go, blockers: blockers),
            reasonSource: .template,
            nextGoodWindow: nextWindow,
            computedAt: conditions.at,
            blockers: blockers,
            caution: ActivityCaution.conditionalCaution(activity: activity, conditions: conditions))
    }

    /// Every good window of `activity` over `forecast`, sorted by start date.
    public func windows(activity: Activity, over forecast: [Conditions]) -> [ActivitySlot] {
        guard let rule = rulesByActivity[activity] else { return [] }
        let samples = forecast.sorted { $0.at < $1.at }
        guard let now = samples.first?.at else { return [] }

        let windows = WindowScanner.allWindows(
            in: samples,
            after: now,
            isGood: { rule.isGo($0) })

        return windows.map { window in
            // Half-open interval: the sample at `window.end` belongs to the next
            // interval, not to this good run.
            let inside = samples.filter { $0.at >= window.start && $0.at < window.end }
            let mean = inside.isEmpty
                ? 0
                : inside.reduce(0) { $0 + rule.score($1) } / Double(inside.count)
            let go = !inside.isEmpty && inside.allSatisfy { rule.isGo($0) }
            return ActivitySlot(activity: activity, window: window, score: mean, go: go)
        }
    }

    /// The blocker that dominates a windowless horizon, or `nil`.
    ///
    /// Used to explain *why* there is no window in the 48 h ahead: the most
    /// frequent blocker the rule emits across the forecast. `nil` when the
    /// forecast is empty or no sample carries a blocker.
    public func dominantBlocker(
        activity: Activity,
        over forecast: [Conditions]) -> ActivityBlocker?
    {
        guard let rule = rulesByActivity[activity] else { return nil }
        return WindowScanner.dominantBlocker(
            in: forecast,
            blockers: { rule.blockers($0) })
    }
}
