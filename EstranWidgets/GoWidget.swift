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
    /// The activity is not offered at the spot (surf inside the Bassin): a
    /// neutral state, never a `Non` and never missing data.
    var isNotOffered: Bool = false
    /// The five answers, for the medium and large widgets (frame 04).
    var lines: [WidgetSnapshot.ActivityLine] = []
    /// Tide, wind, swell, weather, already in French.
    var metrics: [WidgetSnapshot.Metric] = []
    var isSampleData: Bool = false
    /// Stable catalog identifier for the spot, so a tap can open the right place.
    var spotID: String = ""
    /// Optional explicit activity for previews; inferred from `lines`/`isSwimming` when nil.
    var selectedActivity: Activity?
}

struct GoWidgetView: View {
    let entry: GoEntry

    /// 48 pt at the default size, scaled with Dynamic Type: a widget is checked
    /// at AX5 like any other surface.
    @ScaledMetric(relativeTo: .largeTitle) private var badgeSize: CGFloat =
        OceanTypography.widgetGoBadgeBaseSize

    @Environment(\.widgetFamily) private var family
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.levelOfDetail) private var levelOfDetail

    private var isAccessoryFamily: Bool {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            true
        default:
            false
        }
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                GoAccessoryInlineView(entry: entry)
            case .accessoryCircular:
                GoAccessoryCircularView(entry: entry)
            case .accessoryRectangular:
                GoAccessoryRectangularView(entry: entry)
            case .systemLarge:
                GoWidgetLargeView(entry: entry)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            case .systemMedium:
                mediumOrFallbackBody
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            default:
                smallBody
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .containerBackground(for: .widget) {
            if isAccessoryFamily {
                Color.clear
            } else {
                WidgetOceanBackground()
            }
        }
        .widgetURL(entry.openURL)
    }

    @ViewBuilder
    private var mediumOrFallbackBody: some View {
        if !dynamicTypeSize.isAccessibilitySize,
           !entry.isEmpty,
           !entry.isStale,
           entry.lines.count > 1
        {
            mediumBody
        } else {
            smallBody
        }
    }

    @ViewBuilder
    private var smallBody: some View {
        if entry.isSwimming {
            swimmingBody
        } else if entry.isEmpty || entry.isStale {
            staleOrEmptySmallBody
        } else {
            standardBody
        }
    }

    /// Frame 04: the spot on the left, the five answers on the right.
    ///
    /// Only at normal text sizes: at AX sizes five rows cannot fit without
    /// truncating, so the widget falls back to the single answer above.
    private var mediumBody: some View {
        HStack(alignment: .top, spacing: OceanSpacing.sm) {
            VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .widgetAccentedRenderingMode(.accentedDesaturated)
                        .font(OceanTypography.caption)
                        .foregroundStyle(OceanPalette.turquoiseOnGlass)
                        .widgetAccentable()
                        .accessibilityHidden(true)

                    Text(entry.title)
                        .font(OceanTypography.caption)
                        .foregroundStyle(OceanPalette.sand)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if entry.isSwimming {
                    mediumSwimmingColumn
                } else {
                    Text(entry.isUnavailable ? "Données indisponibles" : entry.answer)
                        .font(OceanTypography.rounded(
                            size: (entry.isUnavailable || entry.isNotOffered)
                                ? badgeSize * 0.42 : badgeSize * 0.62))
                        .foregroundStyle(entry.verdictColor)
                        .widgetAccentable()
                        .fixedSize(horizontal: false, vertical: true)

                    if levelOfDetail != .simplified {
                        Text(entry.detail)
                            .font(OceanTypography.smallLabel)
                            .foregroundStyle(OceanPalette.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
                ForEach(entry.lines) { line in
                    HStack(spacing: OceanSpacing.xxs) {
                        Text(line.activity.shortLabel)
                            .foregroundStyle(OceanPalette.white.opacity(0.88))
                        Spacer(minLength: 0)
                        Text(entry.safeLineAnswer(for: line))
                            .foregroundStyle(entry.lineColor(for: line))
                            .multilineTextAlignment(.trailing)
                    }
                    .font(OceanTypography.smallLabel)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(OceanSpacing.xs)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .widgetGlassCard(minimumRadius: 12)
        }
    }

    private var mediumSwimmingColumn: some View {
        let advisory = entry.resolvedSwimmingAdvisory
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .widgetAccentedRenderingMode(.accentedDesaturated)
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.sand)
                    .widgetAccentable()
                    .accessibilityHidden(true)
                Text("Baignade")
                    .font(OceanTypography.tabLabel)
                    .foregroundStyle(OceanPalette.sand)
            }

            Text("Courants : \(advisory.level.shortTitle)")
                .font(OceanTypography.tabLabel)
                .foregroundStyle(OceanPalette.swimmingRiskText(advisory.level))
                .widgetAccentable()
                .fixedSize(horizontal: false, vertical: true)

            Text("Baïnes dangereuses toute l'année.")
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var standardBody: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xs) {
            HStack(spacing: 4) {
                Image(systemName: "mappin.and.ellipse")
                    .widgetAccentedRenderingMode(.accentedDesaturated)
                    .font(OceanTypography.caption)
                    .foregroundStyle(OceanPalette.turquoiseOnGlass)
                    .widgetAccentable()
                    .accessibilityHidden(true)

                Text(entry.title)
                    .font(OceanTypography.caption)
                    .foregroundStyle(OceanPalette.sand)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Text(entry.isUnavailable ? "Données indisponibles" : entry.answer)
                .font(OceanTypography.rounded(
                    size: (entry.isUnavailable || entry.isNotOffered)
                        ? badgeSize * 0.44 : badgeSize))
                .foregroundStyle(entry.verdictColor)
                .widgetAccentable()
                .fixedSize(horizontal: false, vertical: true)

            if levelOfDetail != .simplified {
                Text(entry.detail)
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var staleOrEmptySmallBody: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xs) {
            Text(entry.title)
                .font(OceanTypography.caption)
                .foregroundStyle(OceanPalette.sand)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Text("—")
                .font(OceanTypography.rounded(size: badgeSize))
                .foregroundStyle(OceanPalette.unavailable)
                .widgetAccentable()

            Text(entry.isStale
                ? "Données de plus de 2 h · Ouvre l'app"
                : "Ouvre l'app pour charger les conditions")
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    /// No giant Oui, no green: the level, the conditions line, the non-current
    /// blockers, the coast warning and the disclaimer (Z31).
    private var swimmingBody: some View {
        let advisory = entry.resolvedSwimmingAdvisory

        return VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
            Text(entry.title)
                .font(OceanTypography.caption)
                .foregroundStyle(OceanPalette.sand)
                .fixedSize(horizontal: false, vertical: true)

            Text("Baignade")
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white.opacity(0.75))

            HStack(alignment: .top, spacing: 3) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .widgetAccentedRenderingMode(.accentedDesaturated)
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.sand)
                    .widgetAccentable()
                    .accessibilityHidden(true)
                Text(advisory.level.widgetWarning(for: advisory.region))
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if entry.isStale {
                Text("Données de plus de 2 h · Ouvre l'app")
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.unavailable)
                    .fixedSize(horizontal: false, vertical: true)
            } else if levelOfDetail != .simplified {
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
            }

            Text("Courants : \(entry.isStale ? "—" : advisory.level.shortTitle)")
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.swimmingRiskText(advisory.level))
                .widgetAccentable()
                .fixedSize(horizontal: false, vertical: true)

            Text(SwimmingRiskLevel.disclaimer)
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

struct GoWidget: Widget {
    let kind = "GoWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, provider: GoTimelineProvider()) { entry in
            GoWidgetView(entry: entry)
        }
        .configurationDisplayName("Estran")
        .description("Le verdict ou le niveau de risque, en un coup d'œil.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline
        ])
        .supportedMountingStyles([.elevated, .recessed])
    }
}

#Preview("Small", as: .systemSmall) {
    GoWidget()
} timeline: {
    GoEntry.sample
    GoEntry.sampleSwimming
    GoEntry.sampleStale
    GoEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    GoWidget()
} timeline: {
    GoEntry.sample
    GoEntry.sampleSwimming
    GoEntry.sampleStale
    GoEntry.placeholder
}

#Preview("Large", as: .systemLarge) {
    GoWidget()
} timeline: {
    GoEntry.sample
    GoEntry.sampleSwimming
    GoEntry.sampleStale
    GoEntry.placeholder
}

#Preview("Rectangular", as: .accessoryRectangular) {
    GoWidget()
} timeline: {
    GoEntry.sampleNoGo
    GoEntry.sampleSwimming
    GoEntry.sampleStale
    GoEntry.placeholder
}

#Preview("Circular", as: .accessoryCircular) {
    GoWidget()
} timeline: {
    GoEntry.sample
    GoEntry.sampleSwimming
    GoEntry.sampleStale
    GoEntry.placeholder
}

#Preview("Inline", as: .accessoryInline) {
    GoWidget()
} timeline: {
    GoEntry.sampleNoGo
    GoEntry.sampleSwimming
    GoEntry.sampleStale
    GoEntry.placeholder
}
