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
    /// so a `Non` can never be painted green (VoiceOver audit, F2).
    var isGo: Bool = true
    /// Missing data: a visible state, never a plain `Non`.
    var isUnavailable: Bool = false
    /// The five answers, for the medium widget (frame 04).
    var lines: [WidgetSnapshot.ActivityLine] = []
    /// Tide, wind, swell, weather, already in French.
    var metrics: [WidgetSnapshot.Metric] = []
    var isSampleData: Bool = false
}

struct GoWidgetView: View {
    let entry: GoEntry

    /// 48 pt at the default size, scaled with Dynamic Type: a widget is checked
    /// at AX5 like any other surface.
    @ScaledMetric(relativeTo: .largeTitle) private var badgeSize: CGFloat =
        OceanTypography.widgetGoBadgeBaseSize

    @Environment(\.widgetFamily) private var family
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if family == .systemMedium, entry.lines.count > 1, !dynamicTypeSize.isAccessibilitySize {
                mediumBody
            } else if entry.isSwimming {
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

    /// Frame 04: the spot on the left, the five answers on the right.
    ///
    /// Only at normal text sizes: at AX sizes five rows cannot fit without
    /// truncating, so the widget falls back to the single answer above.
    private var mediumBody: some View {
        HStack(alignment: .top, spacing: OceanSpacing.sm) {
            VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
                Label(entry.title, systemImage: "mappin.and.ellipse")
                    .font(OceanTypography.caption)
                    .foregroundStyle(OceanPalette.sand)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Text(entry.answer)
                    .font(OceanTypography.rounded(size: badgeSize * 0.62))
                    .foregroundStyle(verdictColor)
                    .fixedSize(horizontal: false, vertical: true)

                Text(entry.detail)
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
                ForEach(entry.lines) { line in
                    HStack(spacing: OceanSpacing.xxs) {
                        Text(line.activity.shortLabel)
                            .foregroundStyle(OceanPalette.white.opacity(0.85))
                        Spacer(minLength: 0)
                        Text(line.answer)
                            .foregroundStyle(color(for: line))
                            .multilineTextAlignment(.trailing)
                    }
                    .font(OceanTypography.smallLabel)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    /// Never `oui` for swimming, and never green for a `Non`.
    private var verdictColor: Color {
        if entry.isSwimming {
            return OceanPalette.sand
        }
        if entry.isUnavailable {
            return OceanPalette.unavailable
        }
        return entry.isGo ? OceanPalette.oui : OceanPalette.non
    }

    private func color(for line: WidgetSnapshot.ActivityLine) -> Color {
        if line.activity == .swimming {
            return line.swimmingLevel.map(OceanPalette.swimmingRisk) ?? OceanPalette.sand
        }
        if line.isUnavailable {
            return OceanPalette.unavailable
        }
        return line.isGo ? OceanPalette.oui : OceanPalette.non
    }

    private var standardBody: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xs) {
            Text(entry.title)
                .font(OceanTypography.caption)
                .foregroundStyle(OceanPalette.sand)

            Spacer(minLength: 0)

            Text(entry.answer)
                .font(OceanTypography.rounded(size: badgeSize))
                .foregroundStyle(verdictColor)

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
