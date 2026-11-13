import ActivityKit
import EstranCore
import SwiftUI
import WidgetKit

// MARK: - Lock screen

/// The lock-screen banner: a thin ActivityKit wrapper around `LiveActivityCard`,
/// which draws the verdict as a word + icon + colour, the spot, the window, the
/// app's own caution, and — for swimming — the warning first, the disclaimer
/// last, and never « Oui ».
struct GoLiveActivityView: View {
    let context: ActivityViewContext<GoActivityAttributes>

    var body: some View {
        LiveActivityCard(
            activityName: context.state.activityName,
            spotName: context.attributes.spotName,
            timeZone: context.spotTimeZone,
            isSwimmingFlag: context.state.isSwimming,
            isUnavailable: context.state.isUnavailable,
            isGo: context.state.isGo,
            nextWindowStart: context.state.nextWindowStart,
            swimmingAdvisory: context.state.swimmingAdvisory,
            caution: context.state.caution)
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
/// the activity is swimming, the app's caution, and a visible unavailable state
/// otherwise.
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
                ExpandedCaution(caution: context.state.caution)
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
                ExpandedCaution(caution: context.state.caution)
            }
        }
    }
}

/// The caution row of the expanded island. It reuses the lock-screen line so the
/// two surfaces can never word it differently; no caution, no row.
private struct ExpandedCaution: View {
    let caution: String?

    var body: some View {
        if let caution {
            LiveActivityCautionLine(caution: caution)
        }
    }
}

/// Compact leading. iOS 27 tells the card whether the island is width-limited:
/// the full word fits when it is not, one letter when it is. Swimming and
/// unavailable keep the glyph — there is no room for « baïnes ».
private struct CompactLeading: View {
    let context: ActivityViewContext<GoActivityAttributes>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if ESTRAN_SDK_BEFORE_27
        private var limitedInWidth: Bool {
            false
        }
    #else
        @Environment(\.isDynamicIslandLimitedInWidth) private var limitedInWidth
    #endif

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
