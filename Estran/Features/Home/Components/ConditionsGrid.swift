import EstranCore
import SwiftUI

/// The four condition tiles: tide, wind, swell, weather.
///
/// The row matches `DESIGN_REFERENCE.md` §3.1: four tiles side by side at normal
/// sizes, two columns from `.xLarge` and **one column at accessibility sizes**,
/// so a 17 pt value can grow to AX5 without truncation. Each tile names itself
/// (« Marée », « Vent », « Houle », « Météo »): the icon and « 0,5 m » alone left
/// users guessing what they were looking at (owner feedback on build 5). The
/// visible caption is the short detail the design shows (« descend », « NO »,
/// « période 11 s », « éclaircies »); the accessibility label keeps the full
/// sentence. No fixed height anywhere.
struct ConditionsGrid: View {
    let conditions: Conditions
    /// Column count imposed by the enclosing layout, when it knows it is narrow.
    /// The Duo's side column (~340 pt) holds two readable tiles, not four
    /// squeezed ones; `nil` keeps the Dynamic Type-driven count.
    var preferredColumns: Int?

    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: OceanSpacing.sm)]
        }
        let count = preferredColumns ?? (dynamicTypeSize >= .xLarge ? 2 : 4)
        return Array(
            repeating: GridItem(.flexible(), spacing: OceanSpacing.sm),
            count: max(1, min(count, 4)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xs) {
            LazyVGrid(columns: columns, spacing: OceanSpacing.sm) {
                ConditionTile(
                    icon: FrenchFormat.tideSymbol(conditions.tide),
                    title: "Marée",
                    value: tideHeight,
                    label: FrenchFormat.tideTrendShort(conditions.tide),
                    spoken: "Marée : \(tideHeight), \(FrenchFormat.tideTrend(conditions.tide))")
                ConditionTile(
                    icon: "wind",
                    title: "Vent",
                    value: FrenchFormat.windSpeed(conditions.weather.wind),
                    label: "km/h \(FrenchFormat.windDirection(conditions.weather.wind))",
                    spoken: "Vent : \(FrenchFormat.wind(conditions.weather.wind)), "
                        + "direction \(FrenchFormat.windDirection(conditions.weather.wind))")
                ConditionTile(
                    icon: "water.waves",
                    title: "Houle",
                    value: FrenchFormat.swellHeight(conditions.swell),
                    label: FrenchFormat.swellTileLabel(conditions.swell),
                    spoken: "Houle\(conditions.swell.isEstimated ? " estimée à partir du vent" : "") : "
                        + "\(FrenchFormat.swellHeight(conditions.swell)), "
                        + "période \(FrenchFormat.swellPeriod(conditions.swell))")
                ConditionTile(
                    icon: FrenchFormat.weatherSymbol(conditions.weather.condition),
                    title: "Météo",
                    value: FrenchFormat.temperature(conditions.weather.temperature),
                    label: FrenchFormat.weatherLabel(conditions.weather.condition),
                    spoken: "Météo : \(FrenchFormat.temperature(conditions.weather.temperature)), "
                        + FrenchFormat.weatherLabel(conditions.weather.condition))
            }
            // The day's marnage, from the local model: the one number that says
            // whether the water will really uncover the bank. Absent when the
            // model cannot give it — never a guessed category.
            if let rangeLine {
                Text(rangeLine)
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-estranBaignade") else { return }
            try? await Task.sleep(for: .milliseconds(300))
            app.select(activity: .swimming)
        }
    }

    private var rangeLine: String? {
        app.tideRangeLine(for: conditions)
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
    /// The tile's name, drawn as a small caption above the value.
    let title: String
    let value: String
    let label: String
    /// Full sentence for VoiceOver: the visible caption is a unit detail, not a
    /// sentence, so the combined element cannot rely on it alone.
    let spoken: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
            // Icon and name on one row: the tile keeps three rows (name, value,
            // detail) at four columns, which is the height the design shows.
            HStack(spacing: OceanSpacing.xxs) {
                Image(systemName: icon)
                    .font(OceanTypography.caption)
                    .accessibilityHidden(true)
                Text(title)
                    .font(OceanTypography.smallLabel.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(OceanPalette.sand)

            valueText
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

    /// The measurement, rolled like an instrument dial when it changes.
    ///
    /// Only a value that carries a digit is animated: « — » is a missing
    /// measurement, not a zero, and rolling it against a number would invent a
    /// journey through `0` (`AGENTS.md` invariant 3). Under Reduce Motion the
    /// new value lands in one frame.
    @ViewBuilder
    private var valueText: some View {
        let text = Text(value)
            .font(OceanTypography.bodyEmphasized)
            .foregroundStyle(OceanPalette.white)
            .fixedSize(horizontal: false, vertical: true)
        if value.contains(where: \.isNumber) {
            text
                .contentTransition(.numericText())
                .animation(
                    OceanGlass.animation(
                        .spring(response: 0.38, dampingFraction: 0.9),
                        reduceMotion: reduceMotion),
                    value: value)
        } else {
            text
        }
    }
}
