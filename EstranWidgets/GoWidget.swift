import EstranCore
import SwiftUI
import WidgetKit

struct GoEntry: TimelineEntry {
    let date: Date
    let title: String
    let answer: String
    let detail: String
    /// Swimming is a risk level, never a Oui/Non (product decision, v8).
    var isSwimming: Bool = false
    var swimmingAdvisory: SwimmingAdvisory?
    /// The verdict the answer stands for. The icon and the colour both read it,
    /// so a `Non` can never be painted green (VoiceOver audit, F2). Defaults to
    /// `true` so the M0 placeholder keeps compiling until M5 fills it.
    var isGo: Bool = true
}

struct GoWidgetView: View {
    let entry: GoEntry

    /// 48 pt at the default size, scaled with Dynamic Type: a widget is checked
    /// at AX5 like any other surface.
    @ScaledMetric(relativeTo: .largeTitle) private var badgeSize: CGFloat =
        OceanTypography.widgetGoBadgeBaseSize

    var body: some View {
        Group {
            if entry.isSwimming {
                swimmingBody
            } else {
                standardBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            OceanPalette.backgroundGradient
        }
    }

    private var standardBody: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xs) {
            Text(entry.title)
                .font(OceanTypography.caption)
                .foregroundStyle(OceanPalette.sand)

            Spacer(minLength: 0)

            Text(entry.answer)
                .font(OceanTypography.rounded(size: badgeSize))
                .foregroundStyle(entry.isGo ? OceanPalette.oui : OceanPalette.non)

            Text(entry.detail)
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white.opacity(0.8))
                .lineLimit(2)
        }
    }

    /// No giant Oui, no green: the level, the conditions line, the non-current
    /// blockers, the coast warning and the disclaimer (Z31).
    private var swimmingBody: some View {
        let advisory = entry.swimmingAdvisory ?? SwimmingAdvisory(
            level: .unknown,
            region: .bassin)

        return VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
            Text(entry.title)
                .font(OceanTypography.caption)
                .foregroundStyle(OceanPalette.sand)

            Text("Baignade")
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white.opacity(0.7))

            HStack(alignment: .top, spacing: 2) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.sand)
                    .accessibilityHidden(true)
                Text(advisory.level.widgetWarning(for: advisory.region))
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

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
                .foregroundStyle(OceanPalette.swimmingRiskText(advisory.level))

            Text(SwimmingRiskLevel.disclaimer)
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

struct GoWidget: Widget {
    let kind = "GoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GoTimelineProvider()) { entry in
            GoWidgetView(entry: entry)
        }
        .configurationDisplayName("Estran")
        .description("Le verdict ou le niveau de risque, en un coup d'œil.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    GoWidget()
} timeline: {
    GoEntry.placeholder
}
