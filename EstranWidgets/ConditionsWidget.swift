import SwiftUI
import WidgetKit

struct ConditionsWidgetView: View {
    let entry: GoEntry

    private let columns = [
        GridItem(.flexible(), spacing: OceanSpacing.xs),
        GridItem(.flexible(), spacing: OceanSpacing.xs)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xs) {
            Text(entry.title)
                .font(OceanTypography.caption)
                .foregroundStyle(OceanPalette.sand)

            if entry.metrics.isEmpty {
                Text("Ouvre l'app pour charger les conditions")
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: OceanSpacing.xs) {
                    ForEach(entry.metrics) { metric in
                        VStack(alignment: .leading, spacing: 1) {
                            Image(systemName: metric.symbol)
                                .font(OceanTypography.smallLabel)
                                .foregroundStyle(OceanPalette.sand)
                                .accessibilityHidden(true)
                            Text(metric.value)
                                .font(OceanTypography.bodyEmphasized)
                                .foregroundStyle(OceanPalette.white)
                            Text(metric.caption)
                                .font(OceanTypography.smallLabel)
                                .foregroundStyle(OceanPalette.white.opacity(0.75))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            OceanPalette.backgroundGradient
        }
    }
}

struct ConditionsWidget: Widget {
    let kind = "ConditionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GoTimelineProvider()) { entry in
            ConditionsWidgetView(entry: entry)
        }
        .configurationDisplayName("Conditions")
        .description("Marée, vent, houle et météo du spot choisi.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    ConditionsWidget()
} timeline: {
    GoEntry.placeholder
}
