import Foundation

public enum ReasonSource: String, Codable, Hashable, Sendable {
    case foundationModel
    case template
}

public struct GoDecision: Codable, Hashable, Sendable {
    public let activity: Activity
    public let spot: Spot
    /// Oui / Non.
    public let go: Bool
    /// Pre-threshold score from 0 to 1.
    public let score: Double
    /// Short French explanation.
    public let reason: String
    public let reasonSource: ReasonSource
    public let nextGoodWindow: DateInterval?
    public let computedAt: Date
    /// Hard blockers that forced `Non`, in rule order.
    ///
    /// The UI needs them to tell a plain `Non` from a **data-unavailable**
    /// verdict: « Données indisponibles » is a distinct, visible state, not a
    /// generic refusal. Carrying them here keeps every surface (app, widget,
    /// Live Activity, Siri) on the same reason instead of re-deriving it from
    /// the rule.
    public let blockers: [ActivityBlocker]

    public init(
        activity: Activity,
        spot: Spot,
        go: Bool,
        score: Double,
        reason: String,
        reasonSource: ReasonSource,
        nextGoodWindow: DateInterval?,
        computedAt: Date,
        blockers: [ActivityBlocker] = [])
    {
        self.activity = activity
        self.spot = spot
        self.go = go
        self.score = score
        self.reason = reason
        self.reasonSource = reasonSource
        self.nextGoodWindow = nextGoodWindow
        self.computedAt = computedAt
        self.blockers = blockers
    }

    /// `true` when the verdict is blocked by missing data rather than by the
    /// conditions. The UI must render this as « Données indisponibles », never
    /// as a plain `Non`.
    public var isDataUnavailable: Bool {
        blockers.contains(.dataUnavailable)
            || blockers.contains(.currentDataUnavailable)
    }
}

public struct ActivitySlot: Identifiable, Codable, Hashable, Sendable {
    public let activity: Activity
    public let window: DateInterval
    public let score: Double
    public let go: Bool

    public var id: String {
        "\(activity.rawValue)-\(window.start.timeIntervalSince1970)"
    }

    public init(activity: Activity, window: DateInterval, score: Double, go: Bool) {
        self.activity = activity
        self.window = window
        self.score = score
        self.go = go
    }
}
