import Foundation

/// How the app presents swimming: **a risk level, never a verdict**.
///
/// Swimming in the Bassin or on the Médoc coast is dangerous even in calm
/// weather (tidal currents in the passes, baïnes and rip currents). The engine
/// still computes a go/no-go internally, but no surface may show « Oui » or the
/// green `OceanPalette.oui` next to this activity. The level is derived from the
/// decision's blockers so the app, the widget, the Live Activity and Siri all
/// read the same mapping.
public enum SwimmingRiskLevel: String, Codable, CaseIterable, Hashable, Sendable {
    case low
    case moderate
    case strong
    /// The data cannot estimate the currents (missing or unvalidated
    /// coefficient, missing sea temperature…). Still a warning, never a « Non ».
    case unknown

    /// Maps the engine's decision to the presentation level.
    ///
    /// - `.dataUnavailable` wins over everything: an unestimated current is not
    ///   a low current.
    /// - `.strongCurrent` → strong, `.insufficientMargin` → moderate (the
    ///   uncertainty interval crosses the strong-current band).
    /// - Otherwise the currents are estimated low, even when the overall verdict
    ///   is `Non` for wind, swell, temperature or night.
    public init(decision: GoDecision) {
        if decision.blockers.contains(.currentDataUnavailable) {
            self = .unknown
            return
        }
        if decision.blockers.contains(.strongCurrent) {
            self = .strong
            return
        }
        if decision.blockers.contains(.insufficientMargin) {
            self = .moderate
            return
        }
        self = .low
    }

    /// French label shown in place of the giant Oui/Non.
    public var title: String {
        switch self {
        case .low: "Courants estimés faibles"
        case .moderate: "Courants modérés"
        case .strong: "Courants forts"
        case .unknown: "Courants non estimés"
        }
    }

    /// Explicit, secondary label used under the warning.
    public var label: String {
        switch self {
        case .low: "Courants de marée estimés : faibles"
        case .moderate: "Courants de marée estimés : modérés"
        case .strong: "Courants de marée estimés : forts"
        case .unknown: "Courants de marée non estimés"
        }
    }

    /// One word for the widget, where the warning carries the message.
    public var shortTitle: String {
        switch self {
        case .low: "faibles"
        case .moderate: "modérés"
        case .strong: "forts"
        case .unknown: "non estimés"
        }
    }

    /// SF Symbol paired with the level. The level is never colour-only.
    public var symbolName: String {
        switch self {
        case .low: "water.waves"
        case .moderate: "exclamationmark.triangle"
        case .strong: "exclamationmark.triangle.fill"
        case .unknown: "questionmark.circle"
        }
    }

    /// Permanent warning for the spot's coast, followed by the non-negotiable
    /// sentence. Every surface shows this text, not only the unavailable state.
    public func warning(for region: Region) -> String {
        let base = switch region {
        case .bassin:
            // Baïnes exist in the Bassin too, and the danger is all year.
            "Toute l'année, dans le bassin, les baïnes et les courants de "
                + "marée sont dangereux, même par temps calme. Reste dans une "
                + "zone surveillée, jamais seul, et garde les enfants à portée "
                + "de main."
        case .medoc:
            "Toute l'année, sur l'océan, les baïnes créent des courants "
                + "de retour dangereux, même par temps calme. Baigne entre les "
                + "drapeaux, dans une zone surveillée."
        }
        return base + " " + Self.escape + " " + Self.disclaimer
    }

    /// Always present, on both coasts: what to do if a current carries you.
    public static let escape =
        "Si un courant t'emporte, ne lutte pas : nage parallèle à la plage."

    /// The sentence that keeps the product honest and satisfies App Review
    /// 1.4.1. It is identical on every surface and is never truncated away.
    public static let disclaimer =
        "L'app estime les courants de marée. Elle ne voit ni les baïnes, ni les maîtres-nageurs."

    /// Short form for widgets, where the full warning would not fit. It keeps
    /// the hazard and the escape instruction; the disclaimer is shown separately.
    public func widgetWarning(for region: Region) -> String {
        switch region {
        case .bassin:
            "Toute l'année, baïnes et courants de marée dangereux même par temps "
                + "calme. Reste dans une zone surveillée, jamais seul. " + Self.escape
        case .medoc:
            "Toute l'année, baïnes et courants de retour dangereux même par temps "
                + "calme. Baigne entre les drapeaux. " + Self.escape
        }
    }
}
