import SwiftUI
import WidgetKit

struct ConditionsWidgetView: View {
    let entry: GoEntry

    private let labels = ["Marée", "Vent", "Houle", "Météo"]
    private let columns = [
        GridItem(.flexible(), spacing: OceanSpacing.xs),
        GridItem(.flexible(), spacing: OceanSpacing.xs)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xs) {
            Text(entry.title)
                .font(OceanTypography.caption)
                .foregroundStyle(OceanPalette.sand)

            LazyVGrid(columns: columns, alignment: .leading, spacing: OceanSpacing.xs) {
                ForEach(labels, id: \.self) { label in
                    Text(label)
                        .font(OceanTypography.smallLabel)
                        .foregroundStyle(OceanPalette.white.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
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
