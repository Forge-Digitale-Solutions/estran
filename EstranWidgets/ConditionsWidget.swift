import EstranCore
import SwiftUI
import WidgetKit

struct ConditionsWidgetView: View {
    let entry: GoEntry

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.levelOfDetail) private var levelOfDetail

    private let columns = [
        GridItem(.flexible(), spacing: OceanSpacing.xs),
        GridItem(.flexible(), spacing: OceanSpacing.xs)
    ]

    var body: some View {
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

                Spacer(minLength: OceanSpacing.xxs)

                // 158 pt of medium widget leave no room for a footer under the
                // four tiles: the credit rides on the header's trailing edge,
                // and only at text sizes where the two labels still share a
                // line. The large widget draws it under the metrics.
                if !dynamicTypeSize.isAccessibilitySize {
                    WidgetWeatherCredit(
                        source: entry.weatherSource,
                        isSampleData: entry.isSampleData)
                }
            }

            if entry.metrics.isEmpty || entry.isStale {
                staleOrEmptyMetrics
            } else if dynamicTypeSize.isAccessibilitySize {
                axMetricsList
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: OceanSpacing.xs) {
                    ForEach(entry.metrics) { metric in
                        metricTile(metric)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            WidgetOceanBackground()
        }
        .widgetURL(entry.openURL)
    }

    private var staleOrEmptyMetrics: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
            Text("—")
                .font(OceanTypography.metricValue)
                .foregroundStyle(OceanPalette.unavailable)
                .widgetAccentable()

            Text(entry.isStale
                ? "Données de plus de 2 h · Ouvre l'app"
                : "Ouvre l'app pour charger les conditions")
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var axMetricsList: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
            ForEach(entry.metrics.prefix(2)) { metric in
                HStack(spacing: OceanSpacing.xxs) {
                    Image(systemName: metric.symbol)
                        .widgetAccentedRenderingMode(.accentedDesaturated)
                        .font(OceanTypography.smallLabel)
                        .foregroundStyle(OceanPalette.sand)
                        .widgetAccentable()
                        .accessibilityHidden(true)

                    Text(metric.title.isEmpty
                        ? "\(metric.value) · \(metric.caption)"
                        : "\(metric.title) : \(metric.value) · \(metric.caption)")
                        .font(OceanTypography.smallLabel)
                        .foregroundStyle(OceanPalette.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func metricTile(_ metric: WidgetSnapshot.Metric) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: metric.symbol)
                    .widgetAccentedRenderingMode(.accentedDesaturated)
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.sand)
                    .widgetAccentable()
                    .accessibilityHidden(true)

                if !metric.title.isEmpty {
                    Text(metric.title)
                        .font(OceanTypography.smallLabel)
                        .foregroundStyle(OceanPalette.sand)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            Text(metric.value)
                .font(OceanTypography.bodyEmphasized)
                .foregroundStyle(OceanPalette.white)
                .widgetAccentable()
                .fixedSize(horizontal: false, vertical: true)

            if levelOfDetail != .simplified {
                Text(metric.caption)
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, OceanSpacing.xs)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetGlassTile(cornerRadius: 10)
        .accessibilityElement(children: .combine)
    }
}

struct ConditionsWidget: Widget {
    let kind = "ConditionsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, provider: ConditionsTimelineProvider()) { entry in
            ConditionsWidgetView(entry: entry)
        }
        .configurationDisplayName("Conditions")
        .description("Marée, vent, houle et météo du spot choisi.")
        .supportedFamilies([.systemMedium])
        .supportedMountingStyles([.elevated, .recessed])
    }
}

#Preview("Conditions", as: .systemMedium) {
    ConditionsWidget()
} timeline: {
    GoEntry.sample
    GoEntry.sampleStale
    GoEntry.placeholder
}
