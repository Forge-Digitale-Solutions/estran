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

    private var standardBody: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xs) {
            header
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: OceanSpacing.xs) {
                    verdictBadge
                    details
                }
            } else {
                HStack(alignment: .top, spacing: OceanSpacing.sm) {
                    verdictBadge
                    details
                    Spacer(minLength: 0)
                }
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
    /// answer is its own state, never a `Non`, and it is never green.
    private var verdictBadge: some View {
        let verdict = context.liveVerdict
        let isUnavailable = verdict == .unavailable
        return Label(verdict.word, systemImage: verdict.symbol)
            .font(OceanTypography.rounded(size: isUnavailable ? badgeSize * 0.5 : badgeSize))
            .foregroundStyle(verdict.color)
            .labelStyle(.titleAndIcon)
            .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(verdict.accessibilityLabel)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
            Text(context.attributes.spotName)
                .font(OceanTypography.bodyEmphasized)
                .foregroundStyle(OceanPalette.white)
                .fixedSize(horizontal: false, vertical: true)

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
    }

    /// No « Oui », no green: level, conditions, non-current blockers and the
    /// permanent warning, in that order (warning first).
    private var swimmingBody: some View {
        let advisory = context.swimmingAdvisoryOrUnknown
        return VStack(alignment: .leading, spacing: OceanSpacing.xs) {
            header

            Text(advisory.level.widgetWarning(for: advisory.region))
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white)
                .fixedSize(horizontal: false, vertical: true)

            if let line = advisory.conditionsLine {
                Text(line)
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !advisory.notes.isEmpty {
                Text(advisory.notes.joined(separator: " · "))
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.sand)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Courants : \(advisory.level.shortTitle)")
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.swimmingRisk(advisory.level))

            Text(SwimmingRiskLevel.disclaimer)
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            Text(context.attributes.spotName)
                .font(OceanTypography.caption)
                .foregroundStyle(OceanPalette.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
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
                Text(advisory.level.widgetWarning(for: advisory.region))
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
