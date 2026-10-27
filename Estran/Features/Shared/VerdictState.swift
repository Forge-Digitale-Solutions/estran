import EstranCore
import SwiftUI

/// The three user-facing verdicts.
///
/// « Données indisponibles » is a **state of its own**, not a `Non`: the data
/// cannot answer the question, and the UI says so instead of implying that the
/// conditions are bad.
enum VerdictState: Equatable {
    case go
    case noGo
    case unavailable

    init(decision: GoDecision) {
        if decision.isDataUnavailable {
            self = .unavailable
        } else {
            self = decision.go ? .go : .noGo
        }
    }

    /// The word shown in the giant badge and read by VoiceOver.
    var word: String {
        switch self {
        case .go: "Oui"
        case .noGo: "Non"
        case .unavailable: "Indisponible"
        }
    }

    /// Colour is never the only signal: every state also carries this icon and
    /// its word (`DESIGN_REFERENCE.md` §7.4).
    var symbolName: String {
        switch self {
        case .go: "checkmark.circle.fill"
        case .noGo: "xmark.circle.fill"
        case .unavailable: "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .go: OceanPalette.oui
        case .noGo: OceanPalette.non
        case .unavailable: OceanPalette.unavailable
        }
    }
}
