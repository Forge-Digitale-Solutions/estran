import ActivityKit
import EstranCore
import Foundation
import SwiftUI
import WidgetKit

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

extension ActivityViewContext where Attributes == GoActivityAttributes {
    /// Swimming when the state says so, when an advisory travels with it, or
    /// when the activity name is « Baignade ». Three independent signals, so a
    /// single stale flag cannot turn the card into a verdict.
    var isSwimmingActivity: Bool {
        state.isSwimming
            || state.swimmingAdvisory != nil
            || state.activityName == EstranCore.Activity.swimming.displayName
    }

    var swimmingAdvisoryOrUnknown: SwimmingAdvisory {
        state.swimmingAdvisory ?? SwimmingAdvisory(level: .unknown, region: .bassin)
    }

    var liveVerdict: LiveActivityVerdict {
        if isSwimmingActivity {
            return .swimming(swimmingAdvisoryOrUnknown.level)
        }
        if state.isUnavailable {
            return .unavailable
        }
        return state.isGo ? .go : .noGo
    }

    /// The card shows times in the spot's zone, never the traveller's device
    /// zone: an Arcachon window is read in Arcachon time.
    var spotTimeZone: TimeZone {
        SpotCatalog.spot(id: attributes.spotID)?.timezone ?? .current
    }
}

/// « Prochain créneau · 14 h 12 » in the spot's zone. The time is a separate
/// `Text` so it rolls with `.numericText` instead of snapping; Reduce Motion
/// drops the roll and keeps the value.
struct LiveActivityWindowLine: View {
    let start: Date
    let timeZone: TimeZone
    let color: Color
    let reduceMotion: Bool

    var body: some View {
        if let time = Self.time(start, in: timeZone) {
            HStack(spacing: 2) {
                Text("Prochain créneau ·")
                Text(time)
                    .contentTransition(reduceMotion ? .identity : .numericText())
            }
            .font(OceanTypography.caption)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Prochain créneau à \(time)")
        }
    }

    /// « 14 h 12 », the app's 24-hour form. `nil` when the calendar cannot
    /// produce both components: a made-up time would invent a value.
    private static func time(_ date: Date, in timeZone: TimeZone) -> String? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = parts.hour, let minute = parts.minute else {
            return nil
        }
        return "\(hour) h \(String(format: "%02d", minute))"
    }
}

/// The lock-screen banner's Liquid Glass panel.
///
/// `GlassStyles.swift` is not compiled into the widget extension, so the four
/// looks are mirrored here with the same numbers as `GlassAppearance`: glass by
/// default, opaque `navyInk` under Reduce Transparency, a 45 % `navyInk`
/// backing plus a 1.5 pt white 0.5 border under Increase Contrast.
struct LiveActivityBanner: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
    }

    func body(content: Content) -> some View {
        Group {
            if reduceTransparency {
                content.background(OceanPalette.navyInk, in: shape)
            } else if colorSchemeContrast == .increased {
                content
                    .background(OceanPalette.navyInk.opacity(0.45), in: shape)
                    .glassEffect(.regular, in: shape)
            } else {
                content.glassEffect(.regular, in: shape)
            }
        }
        .overlay {
            if reduceTransparency || colorSchemeContrast == .increased {
                shape.strokeBorder(
                    OceanPalette.white.opacity(colorSchemeContrast == .increased ? 0.5 : 0.18),
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 1)
            }
        }
    }
}
