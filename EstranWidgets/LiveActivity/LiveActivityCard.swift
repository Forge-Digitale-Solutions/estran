import EstranCore
import Foundation
import SwiftUI
import WidgetKit

// MARK: - Lock screen

/// The lock-screen banner, from plain values rather than an `ActivityViewContext`
/// so the exact layout can be rendered and measured at 370 and 393 pt in the
/// test target (`LiveActivityRenderTests`). `GoLiveActivityView` is the thin
/// ActivityKit wrapper that feeds it.
struct LiveActivityCard: View {
    let activityName: String
    let spotName: String
    let timeZone: TimeZone
    /// The state's raw swimming flag; the card also treats an advisory or the
    /// « Baignade » name as swimming, so a stale flag alone cannot produce a
    /// verdict.
    let isSwimmingFlag: Bool
    let isUnavailable: Bool
    let isGo: Bool
    let nextWindowStart: Date?
    let swimmingAdvisory: SwimmingAdvisory?
    /// The app's composed caution (night, light rain, the Bassin passes), or
    /// `nil`. Never shown for swimming: its advisory already carries the warning.
    let caution: String?

    @ScaledMetric(relativeTo: .largeTitle) private var badgeSize: CGFloat =
        OceanTypography.widgetGoBadgeBaseSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.levelOfDetail) private var levelOfDetail

    var body: some View {
        Group {
            if isSwimming {
                swimmingBody
            } else {
                standardBody
            }
        }
        .padding(OceanSpacing.md)
        .modifier(LiveActivityBanner())
        .padding(OceanSpacing.xs)
        .activityBackgroundTint(OceanPalette.oceanDeepBottom)
        .activitySystemActionForegroundColor(OceanPalette.turquoise)
    }

    private var isSwimming: Bool {
        LiveActivityCardState.isSwimming(
            activityName: activityName,
            isSwimming: isSwimmingFlag,
            advisory: swimmingAdvisory)
    }

    private var advisoryOrUnknown: SwimmingAdvisory {
        swimmingAdvisory ?? SwimmingAdvisory(level: .unknown, region: .bassin)
    }

    private var verdict: LiveActivityVerdict {
        LiveActivityVerdict(
            isSwimming: isSwimming,
            isUnavailable: isUnavailable,
            isGo: isGo,
            level: advisoryOrUnknown.level)
    }

    /// The verdict keeps its full width; the spot name column yields, and the
    /// window and the caution get their own full-width lines. At accessibility
    /// sizes, and for the long « Données indisponibles » word, everything stacks
    /// instead — the verdict word never wraps and never breaks mid-word.
    ///
    /// With a caution the window moves under the spot name, beside the verdict:
    /// the card must stay inside the ~160 pt lock-screen height, and the extra
    /// row would push the longest caution (the Bassin passes) past it.
    private var standardBody: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
            header
            if dynamicTypeSize.isAccessibilitySize || isUnavailable {
                verdictBadge
                details
            } else if caution != nil {
                HStack(alignment: .firstTextBaseline, spacing: OceanSpacing.sm) {
                    verdictBadge
                    VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
                        spotNameLabel
                        windowLine
                    }
                    Spacer(minLength: 0)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: OceanSpacing.sm) {
                    verdictBadge
                    spotNameLabel
                    Spacer(minLength: 0)
                }
                windowLine
            }
            if let caution {
                LiveActivityCautionLine(caution: caution)
            }
        }
    }

    /// Activity first, then the local-model line: it says what the app is and
    /// never implies an official source (invariant 2).
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: OceanSpacing.xs) {
            Text(activityName)
                .font(OceanTypography.caption)
                .foregroundStyle(OceanPalette.sand)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if levelOfDetail != .simplified {
                Text("Modèle local")
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.white.opacity(0.6))
            }
        }
    }

    /// The giant verdict is the card's signature, but a caution adds a row the
    /// ~160 pt lock-screen card cannot afford: at the standard sizes the verdict
    /// yields a quarter of its size (36 pt at the default scale, still the
    /// largest thing on the card) so the caution keeps its full width and its
    /// words. At accessibility sizes the card grows anyway, so the verdict keeps
    /// its full size and stays the dominant element.
    private var displayedBadgeSize: CGFloat {
        guard caution != nil, !dynamicTypeSize.isAccessibilitySize else {
            return badgeSize
        }
        return badgeSize * 0.75
    }

    /// The verdict: an icon, a word and a colour, never colour alone. A missing
    /// answer is its own state, never a `Non`, and it is never green. The word
    /// is one token (`fixedSize` horizontal): at 370 pt it used to break into
    /// « No » / « n ».
    private var verdictBadge: some View {
        let badgeVerdict = verdict
        let isUnavailable = badgeVerdict == .unavailable
        return Label(badgeVerdict.word, systemImage: badgeVerdict.symbol)
            .font(OceanTypography.rounded(
                size: isUnavailable ? displayedBadgeSize * 0.5 : displayedBadgeSize))
            .foregroundStyle(badgeVerdict.color)
            .labelStyle(.titleAndIcon)
            .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
            .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: false)
            .layoutPriority(1)
            .accessibilityLabel(verdict.accessibilityLabel)
    }

    private var spotNameLabel: some View {
        Text(spotName)
            .font(OceanTypography.bodyEmphasized)
            .foregroundStyle(OceanPalette.white)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
            spotNameLabel
            windowLine
        }
    }

    @ViewBuilder
    private var windowLine: some View {
        if isUnavailable {
            Text("Créneaux indisponibles")
                .font(OceanTypography.caption)
                .foregroundStyle(OceanPalette.unavailable)
                .fixedSize(horizontal: false, vertical: true)
        } else if let start = nextWindowStart {
            LiveActivityWindowLine(
                start: start,
                timeZone: timeZone,
                color: OceanPalette.sand,
                reduceMotion: reduceMotion)
        }
    }

    /// No « Oui », no green. The system caps the lock-screen card at roughly
    /// 160 pt, so this is the short form of the warning — hazard first, then the
    /// level, then the permanent disclaimer — not the full paragraph the app
    /// card shows. The expanded island carries the same short copy.
    private var swimmingBody: some View {
        let advisory = advisoryOrUnknown
        return VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
            header

            Text(LiveActivitySwimming.danger)
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white)
                .fixedSize(horizontal: false, vertical: true)

            // Small text on the translucent banner: the on-glass token, never
            // the vivid Figma hue (which stays for large glyphs). `non`
            // #FF6B5B measured under 4.5:1 there; `nonOnGlass` #FFBAB2 clears
            // it (docs/accessibility/contrast-audit.md, A20/B21/B23/B50).
            Text("Courants : \(advisory.level.shortTitle)")
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.swimmingRiskText(advisory.level))
                .fixedSize(horizontal: false, vertical: true)

            Text(SwimmingRiskLevel.disclaimer)
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            Text(spotName)
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Caution

/// One caution line, shared by the lock screen and the expanded island: a
/// warning glyph plus the app's own sentence, `sand` on glass (the token the
/// answer card uses for the same row). It never truncates: the sentence wraps,
/// and the start of the caution is what the reader needs first.
struct LiveActivityCautionLine: View {
    let caution: String

    var body: some View {
        HStack(alignment: .top, spacing: OceanSpacing.xxs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.sand)
                .accessibilityHidden(true)
            Text(caution)
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.sand)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The short swimming warning shared by the lock screen and the expanded
/// island. It keeps the hazard and « même par temps calme »; the full paragraph
/// lives in the app card, the widget and VoiceOver's advisory sentence.
enum LiveActivitySwimming {
    static let danger = "Danger baïnes toute l'année, même par temps calme."
}

// MARK: - Window

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
            // One `Text`, never two in an `HStack`: at 370 pt the old pair
            // wrapped into « Prochain créneau » / « · » / « 8 h 38 ».
            Text("Prochain créneau · \(time)")
                .font(OceanTypography.caption)
                .foregroundStyle(color)
                .contentTransition(reduceMotion ? .identity : .numericText())
                .fixedSize(horizontal: false, vertical: true)
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

// MARK: - Glass

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
