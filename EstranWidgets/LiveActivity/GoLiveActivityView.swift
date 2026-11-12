import ActivityKit
import EstranCore
import SwiftUI
import WidgetKit

// MARK: - Lock screen

/// The lock-screen banner: a glass panel over the ocean tint, the verdict as a
/// word + icon + colour, the spot, the window, and — for swimming — the warning
/// first, the disclaimer last, and never « Oui ».
struct GoLiveActivityView: View {
    let context: ActivityViewContext<GoActivityAttributes>

    @ScaledMetric(relativeTo: .largeTitle) private var badgeSize: CGFloat =
        OceanTypography.widgetGoBadgeBaseSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.levelOfDetail) private var levelOfDetail

    var body: some View {
        Group {
            if context.isSwimmingActivity {
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

    /// The verdict keeps its full width; the spot name column yields, and the
    /// window gets its own full-width line. At accessibility sizes, and for the
    /// long « Données indisponibles » word, everything stacks instead — the
    /// verdict word never wraps and never breaks mid-word.
    private var standardBody: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xs) {
            header
            if dynamicTypeSize.isAccessibilitySize || context.state.isUnavailable {
                verdictBadge
                details
            } else {
                HStack(alignment: .firstTextBaseline, spacing: OceanSpacing.sm) {
                    verdictBadge
                    spotName
                    Spacer(minLength: 0)
                }
                windowLine
            }
        }
    }

    /// Activity first, then the local-model line: it says what the app is and
    /// never implies an official source (invariant 2).
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: OceanSpacing.xs) {
            Text(context.state.activityName)
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

    /// The verdict: an icon, a word and a colour, never colour alone. A missing
    /// answer is its own state, never a `Non`, and it is never green. The word
    /// is one token (`fixedSize` horizontal): at 370 pt it used to break into
    /// « No » / « n ».
    private var verdictBadge: some View {
        let verdict = context.liveVerdict
        let isUnavailable = verdict == .unavailable
        return Label(verdict.word, systemImage: verdict.symbol)
            .font(OceanTypography.rounded(size: isUnavailable ? badgeSize * 0.5 : badgeSize))
            .foregroundStyle(verdict.color)
            .labelStyle(.titleAndIcon)
            .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
            .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: false)
            .layoutPriority(1)
            .accessibilityLabel(verdict.accessibilityLabel)
    }

    private var spotName: some View {
        Text(context.attributes.spotName)
            .font(OceanTypography.bodyEmphasized)
            .foregroundStyle(OceanPalette.white)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
            spotName
            windowLine
        }
    }

    @ViewBuilder
    private var windowLine: some View {
        if context.state.isUnavailable {
            Text("Créneaux indisponibles")
                .font(OceanTypography.caption)
                .foregroundStyle(OceanPalette.unavailable)
                .fixedSize(horizontal: false, vertical: true)
        } else if let start = context.state.nextWindowStart {
            LiveActivityWindowLine(
                start: start,
                timeZone: context.spotTimeZone,
                color: OceanPalette.sand,
                reduceMotion: reduceMotion)
        }
    }

    /// No « Oui », no green. The system caps the lock-screen card at roughly
    /// 160 pt, so this is the short form of the warning — hazard first, then the
    /// level, then the permanent disclaimer — not the full paragraph the app
    /// card shows. The expanded island carries the same short copy.
    private var swimmingBody: some View {
        let advisory = context.swimmingAdvisoryOrUnknown
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

            Text(context.attributes.spotName)
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The short swimming warning shared by the lock screen and the expanded
/// island. It keeps the hazard and « même par temps calme »; the full paragraph
/// lives in the app card, the widget and VoiceOver's advisory sentence.
private enum LiveActivitySwimming {
    static let danger = "Danger baïnes toute l'année, même par temps calme."
}

// MARK: - Dynamic Island

struct GoLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GoActivityAttributes.self) { context in
            GoLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.spotName)
                        .font(OceanTypography.caption)
                        .foregroundStyle(OceanPalette.white)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottom(context: context)
                }
            } compactLeading: {
                CompactLeading(context: context)
            } compactTrailing: {
                Text(context.attributes.spotName)
                    .font(OceanTypography.tabLabel)
                    .foregroundStyle(OceanPalette.white)
                    // Documented truncation exception (DESIGN_REFERENCE §2.1):
                    // the compact trailing region is width-constrained by the
                    // system, and the full name is in the expanded island.
                    .lineLimit(1)
            } minimal: {
                MinimalGlyph(context: context)
            }
            .keylineTint(OceanPalette.turquoise)
        }
    }
}

/// Expanded leading: a `Label` whose word is the verdict (or « Baignade »), so
/// VoiceOver never hears a bare glyph (VoiceOver audit, F3).
private struct ExpandedLeading: View {
    let context: ActivityViewContext<GoActivityAttributes>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let verdict = context.liveVerdict
        Label(verdict.word, systemImage: verdict.symbol)
            .font(OceanTypography.metricValue)
            .foregroundStyle(verdict.color)
            .labelStyle(.titleAndIcon)
            .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
            .accessibilityLabel(verdict.accessibilityLabel)
    }
}

/// Expanded bottom: the window when there is one, the swimming dossier when
/// the activity is swimming, and a visible unavailable state otherwise.
private struct ExpandedBottom: View {
    let context: ActivityViewContext<GoActivityAttributes>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if context.isSwimmingActivity {
            let advisory = context.swimmingAdvisoryOrUnknown
            VStack(alignment: .leading, spacing: 1) {
                Text(LiveActivitySwimming.danger)
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Courants : \(advisory.level.shortTitle)")
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.swimmingRisk(advisory.level))
                // Same permanent disclaimer as the lock screen: the expanded
                // island must not be the one surface that drops it (F6).
                Text(SwimmingRiskLevel.disclaimer)
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if context.state.isUnavailable {
            VStack(alignment: .leading, spacing: 1) {
                Text("Données indisponibles")
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.unavailable)
                Text(context.state.activityName)
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.white.opacity(0.8))
            }
        } else {
            VStack(alignment: .leading, spacing: 1) {
                Text(context.state.activityName)
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.sand)
                if let start = context.state.nextWindowStart {
                    LiveActivityWindowLine(
                        start: start,
                        timeZone: context.spotTimeZone,
                        color: OceanPalette.white.opacity(0.8),
                        reduceMotion: reduceMotion)
                }
            }
        }
    }
}

/// Compact leading. iOS 27 tells the card whether the island is width-limited:
/// the full word fits when it is not, one letter when it is. Swimming and
/// unavailable keep the glyph — there is no room for « baïnes ».
private struct CompactLeading: View {
    let context: ActivityViewContext<GoActivityAttributes>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isDynamicIslandLimitedInWidth) private var limitedInWidth

    var body: some View {
        let verdict = context.liveVerdict
        switch verdict {
        case .swimming, .unavailable:
            Image(systemName: verdict.symbol)
                .font(OceanTypography.tabLabel)
                .foregroundStyle(verdict.color)
                .accessibilityLabel(verdict.accessibilityLabel)
        case .go, .noGo:
            Text(limitedInWidth ? verdict.compactLetter : verdict.word)
                .font(OceanTypography.tabLabel)
                .foregroundStyle(verdict.color)
                .contentTransition(reduceMotion ? .identity : .opacity)
                // The letter is a width compromise; VoiceOver reads the verdict
                // (VoiceOver audit, F3).
                .accessibilityLabel(verdict.accessibilityLabel)
        }
    }
}

/// Minimal: one glyph, the same symbol as the expanded leading, with its own
/// spoken label — a letter would read as an initial, not a verdict.
private struct MinimalGlyph: View {
    let context: ActivityViewContext<GoActivityAttributes>

    var body: some View {
        let verdict = context.liveVerdict
        Image(systemName: verdict.symbol)
            .font(OceanTypography.tabLabel)
            .foregroundStyle(verdict.color)
            .accessibilityLabel(verdict.accessibilityLabel)
    }
}
