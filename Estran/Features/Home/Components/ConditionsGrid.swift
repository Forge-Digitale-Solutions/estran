import EstranCore
import SwiftUI

/// The four condition tiles: tide, wind, swell, weather.
///
/// The row matches `DESIGN_REFERENCE.md` §3.1: four tiles side by side at normal
/// sizes, two columns from `.xLarge` and **one column at accessibility sizes**,
/// so a 17 pt value can grow to AX5 without truncation. The visible caption is
/// the short unit detail the Figma frame shows (« basse », « NO », « 11 s »,
/// « éclaircies »); the accessibility label keeps the full sentence. No fixed
/// height anywhere.
struct ConditionsGrid: View {
    let conditions: Conditions

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: OceanSpacing.sm)]
        }
        let count = dynamicTypeSize >= .xLarge ? 2 : 4
        return Array(
            repeating: GridItem(.flexible(), spacing: OceanSpacing.sm),
            count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: OceanSpacing.sm) {
            ConditionTile(
                icon: "water.waves",
                value: tideHeight,
                label: FrenchFormat.tideTrendShort(conditions.tide),
                spoken: "Marée : \(tideHeight), \(FrenchFormat.tideTrend(conditions.tide))")
            ConditionTile(
                icon: "wind",
                value: FrenchFormat.windSpeed(conditions.weather.wind),
                label: "km/h \(FrenchFormat.windDirection(conditions.weather.wind))",
                spoken: "Vent : \(FrenchFormat.wind(conditions.weather.wind)), "
                    + "direction \(FrenchFormat.windDirection(conditions.weather.wind))")
            ConditionTile(
                icon: "wave.3.right",
                value: FrenchFormat.swellHeight(conditions.swell),
                label: FrenchFormat.swellPeriod(conditions.swell),
                spoken: "Houle : \(FrenchFormat.swellHeight(conditions.swell)), "
                    + "période \(FrenchFormat.swellPeriod(conditions.swell))")
            ConditionTile(
                icon: FrenchFormat.weatherSymbol(conditions.weather.condition),
                value: FrenchFormat.temperature(conditions.weather.temperature),
                label: FrenchFormat.weatherLabel(conditions.weather.condition),
                spoken: "Météo : \(FrenchFormat.temperature(conditions.weather.temperature)), "
                    + FrenchFormat.weatherLabel(conditions.weather.condition))
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
    /// Full sentence for VoiceOver: the visible caption is a unit detail, not a
    /// sentence, so the combined element cannot rely on it alone.
    let spoken: String

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
        .padding(.vertical, OceanSpacing.sm)
        .padding(.horizontal, OceanSpacing.xs)
        .oceanGlassCard(cornerRadius: OceanGlass.tileCornerRadius)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }
}
