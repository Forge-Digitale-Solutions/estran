import EstranCore
import SwiftUI

/// What the Live Activity draws, derived only from the content state.
///
/// **Invariant 1, enforced where the pixels are.** The controller already
/// refuses to start a card for swimming, but the view does not trust it: a
/// swimming card has no `go` case here, so « Oui » and the go green cannot be
/// produced even if a state said `isGo == true`. Unavailable is a state of its
/// own, never a `Non` (invariant 4).
enum LiveActivityVerdict: Equatable {
    case go
    case noGo
    case unavailable
    case swimming(SwimmingRiskLevel)

    /// The verdict a card shows, from the three swimming signals, the
    /// unavailable flag and the go flag — in that order of authority.
    init(isSwimming: Bool, isUnavailable: Bool, isGo: Bool, level: SwimmingRiskLevel) {
        if isSwimming {
            self = .swimming(level)
        } else if isUnavailable {
            self = .unavailable
        } else {
            self = isGo ? .go : .noGo
        }
    }

    var word: String {
        switch self {
        case .go: "Oui"
        case .noGo: "Non"
        case .unavailable: "Données indisponibles"
        case .swimming: "Baignade"
        }
    }

    /// One letter for a width-limited compact island. Never a verdict for
    /// swimming: that case draws the alert glyph instead.
    var compactLetter: String {
        switch self {
        case .go: "O"
        case .noGo: "N"
        case .unavailable, .swimming: "!"
        }
    }

    var symbol: String {
        switch self {
        case .go: "checkmark.circle.fill"
        case .noGo: "xmark.circle.fill"
        case .unavailable, .swimming: "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .go: OceanPalette.oui
        case .noGo: OceanPalette.non
        case .unavailable: OceanPalette.unavailable
        case let .swimming(level): OceanPalette.swimmingRisk(level)
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .go: "Oui"
        case .noGo: "Non"
        case .unavailable: "Données indisponibles"
        case .swimming: "Baignade : risque de courants"
        }
    }
}

/// The three signals that make a card a swimming card. Kept next to the view
/// that draws it, so the card refuses « Oui » on its own even if the controller
/// and the state disagree.
enum LiveActivityCardState {
    static func isSwimming(
        activityName: String,
        isSwimming: Bool,
        advisory: SwimmingAdvisory?) -> Bool
    {
        isSwimming
            || advisory != nil
            || activityName == EstranCore.Activity.swimming.displayName
    }
}
