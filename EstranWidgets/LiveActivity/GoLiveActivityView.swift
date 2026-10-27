import ActivityKit
import EstranCore
import SwiftUI
import WidgetKit

struct GoLiveActivityView: View {
    let context: ActivityViewContext<GoActivityAttributes>

    @ScaledMetric(relativeTo: .largeTitle) private var badgeSize: CGFloat =
        OceanTypography.widgetGoBadgeBaseSize

    var body: some View {
        Group {
            if context.state.isSwimming {
                swimmingBody
            } else {
                standardBody
            }
        }
        .padding(OceanSpacing.md)
        .activityBackgroundTint(OceanPalette.oceanDeepBottom)
        .activitySystemActionForegroundColor(OceanPalette.turquoise)
    }

    private var standardBody: some View {
        HStack(spacing: OceanSpacing.sm) {
            Text(context.state.isGo ? "Oui" : "Non")
                .font(OceanTypography.rounded(size: badgeSize))
                .foregroundStyle(context.state.isGo ? OceanPalette.oui : OceanPalette.non)

            VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
                Text(context.attributes.spotName)
                    .font(OceanTypography.bodyEmphasized)
                    .foregroundStyle(OceanPalette.white)
                Text(context.state.activityName)
                    .font(OceanTypography.caption)
                    .foregroundStyle(OceanPalette.sand)
            }

            Spacer(minLength: 0)
        }
    }

    /// No « Oui », no green: level, conditions, non-current blockers and warning.
    private var swimmingBody: some View {
        let advisory = context.state.swimmingAdvisory ?? SwimmingAdvisory(
            level: .unknown,
            region: .bassin)

        return VStack(alignment: .leading, spacing: OceanSpacing.xs) {
            HStack {
                Text("Baignade")
                    .font(OceanTypography.caption)
                    .foregroundStyle(OceanPalette.sand)
                Spacer(minLength: 0)
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(OceanPalette.sand)
                    .accessibilityHidden(true)
            }

            // Warning first, then the facts, then the secondary level.
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
        }
    }
}

struct GoLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GoActivityAttributes.self) { context in
            GoLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if context.state.isSwimming {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(OceanTypography.metricValue)
                            .foregroundStyle(
                                OceanPalette.swimmingRisk(context.state.swimmingAdvisory?.level ?? .unknown))
                    } else {
                        Text(context.state.isGo ? "Oui" : "Non")
                            .font(OceanTypography.metricValue)
                            .foregroundStyle(
                                context.state.isGo ? OceanPalette.oui : OceanPalette.non)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.spotName)
                        .font(OceanTypography.caption)
                        .foregroundStyle(OceanPalette.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isSwimming {
                        let advisory = context.state.swimmingAdvisory
                        VStack(alignment: .leading, spacing: 1) {
                            Text(advisory?.level.widgetWarning(for: advisory?.region ?? .bassin)
                                ?? SwimmingRiskLevel.unknown.widgetWarning(for: .bassin))
                                .font(OceanTypography.smallLabel)
                                .foregroundStyle(OceanPalette.white)
                            Text("Courants : \(advisory?.level.shortTitle ?? SwimmingRiskLevel.unknown.shortTitle)")
                                .font(OceanTypography.smallLabel)
                                .foregroundStyle(
                                    OceanPalette.swimmingRisk(advisory?.level ?? .unknown))
                        }
                    } else {
                        Text(context.state.activityName)
                            .font(OceanTypography.smallLabel)
                            .foregroundStyle(OceanPalette.sand)
                    }
                }
            } compactLeading: {
                if context.state.isSwimming {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(OceanTypography.tabLabel)
                        .foregroundStyle(OceanPalette.sand)
                } else {
                    Text(context.state.isGo ? "O" : "N")
                        .font(OceanTypography.tabLabel)
                        .foregroundStyle(
                            context.state.isGo ? OceanPalette.oui : OceanPalette.non)
                }
            } compactTrailing: {
                Text(context.attributes.spotName)
                    .font(OceanTypography.tabLabel)
                    .foregroundStyle(OceanPalette.white)
                    .lineLimit(1)
            } minimal: {
                if context.state.isSwimming {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(OceanTypography.tabLabel)
                        .foregroundStyle(OceanPalette.sand)
                } else {
                    Text(context.state.isGo ? "O" : "N")
                        .font(OceanTypography.tabLabel)
                        .foregroundStyle(
                            context.state.isGo ? OceanPalette.oui : OceanPalette.non)
                }
            }
        }
    }
}
