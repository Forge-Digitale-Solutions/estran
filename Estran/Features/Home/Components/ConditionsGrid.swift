import EstranCore
import SwiftUI

/// The four condition tiles: tide, wind, swell, weather.
///
/// The grid is two columns at normal sizes and **one column at accessibility
/// sizes**, so a 17 pt value can grow to AX5 without truncation. No fixed
/// height anywhere.
struct ConditionsGrid: View {
    let conditions: Conditions

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: OceanSpacing.sm)]
        }
        return [
            GridItem(.flexible(), spacing: OceanSpacing.sm),
            GridItem(.flexible(), spacing: OceanSpacing.sm)
        ]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: OceanSpacing.sm) {
            ConditionTile(
                icon: "water.waves",
                value: tideHeight,
                label: "Marée · \(FrenchFormat.tideTrend(conditions.tide))")
            ConditionTile(
                icon: "wind",
                value: FrenchFormat.wind(conditions.weather.wind),
                label: "Vent · \(FrenchFormat.windDirection(conditions.weather.wind))")
            ConditionTile(
                icon: "wave.3.right",
                value: FrenchFormat.swellHeight(conditions.swell),
                label: "Houle · \(FrenchFormat.swellPeriod(conditions.swell))")
            ConditionTile(
                icon: FrenchFormat.weatherSymbol(conditions.weather.condition),
                value: FrenchFormat.temperature(conditions.weather.temperature),
                label: "Météo · \(FrenchFormat.weatherLabel(conditions.weather.condition))")
        }
    }

    /// A missing tide event is not 0.0 m: zero is a real height (the chart
    /// datum), not a neutral placeholder. Show « — » instead (early M3 review,
    /// point 3).
    private var tideHeight: String {
        guard let height = conditions.tide.current?.height else { return "—" }
        return "\(FrenchFormat.height(height)) m"
    }
}

struct ConditionTile: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
            Image(systemName: icon)
                .font(OceanTypography.body)
                .foregroundStyle(OceanPalette.sand)
                .accessibilityHidden(true)
            Text(value)
                .font(OceanTypography.bodyEmphasized)
                .foregroundStyle(OceanPalette.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(label)
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(OceanSpacing.md)
        .oceanGlassCard(cornerRadius: OceanGlass.tileCornerRadius)
        .accessibilityElement(children: .combine)
    }
}
