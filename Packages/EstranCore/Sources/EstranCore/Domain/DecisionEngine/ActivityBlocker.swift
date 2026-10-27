import Foundation

/// Reasons that can force a `Non`, independently of the numeric score.
///
/// Blockers are ordered by the rule that produces them; the first one drives
/// the short reason shown to the user.
public enum ActivityBlocker: String, Codable, CaseIterable, Hashable, Sendable {
    case storm
    case dataUnavailable
    /// The tide data needed to estimate the current is missing or invalid.
    /// Distinct from `.dataUnavailable` (e.g. a missing sea temperature), which
    /// must not mute the current level.
    case currentDataUnavailable
    case rain
    case wind
    case coefficient
    case tideTiming
    case waveTooSmall
    case waveTooLarge
    case wavePeriod
    case swellTooLarge
    case swellDirection
    case onshoreWind
    case fog
    case visibility
    case waterLevel
    case waterTemperature
    case temperature
    case night
    case strongCurrent
    /// The nominal conditions pass, but the uncertainty envelope straddles a
    /// safety threshold, so the verdict fails closed.
    case insufficientMargin

    /// Short French label used by the deterministic reason template.
    public var shortLabel: String {
        switch self {
        case .storm:
            "Orage"
        case .dataUnavailable:
            "Données indisponibles"
        case .currentDataUnavailable:
            "Courants non estimés"
        case .rain:
            "Pluie"
        case .wind:
            "Vent trop fort"
        case .coefficient:
            "Coefficient trop faible"
        case .tideTiming:
            "Pas à marée basse"
        case .waveTooSmall:
            "Mer trop plate"
        case .waveTooLarge:
            "Houle trop forte"
        case .wavePeriod:
            "Période de houle inadaptée"
        case .swellTooLarge:
            "Houle trop forte"
        case .swellDirection:
            "Houle mal orientée"
        case .onshoreWind:
            "Vent onshore"
        case .fog:
            "Brouillard"
        case .visibility:
            "Visibilité insuffisante"
        case .waterLevel:
            "Pas assez d'eau"
        case .waterTemperature:
            "Eau trop froide"
        case .temperature:
            "Température inadaptée"
        case .night:
            "Trop sombre"
        case .strongCurrent:
            "Courant trop fort"
        case .insufficientMargin:
            "Marge insuffisante"
        }
    }
}
