import EstranCore
import SwiftUI

/// The swimming card: **the warning is the product, the current level is
/// secondary.**
///
/// Reading order: title → warning → conditions → level. The giant green/coral
/// verdict never appears here, and the level is rendered as a caption, never as
/// the `metricValue` that used to dominate the card. Swimming is dangerous all
/// year; nothing in the layout may suggest that off-season is safer.
struct SwimmingAdvisoryCard: View {
    let advisory: SwimmingAdvisory

    var body: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.sm) {
            Text("BAIGNADE")
                .font(OceanTypography.smallLabel)
                .tracking(1.2)
                .foregroundStyle(OceanPalette.white.opacity(0.7))

            HStack(alignment: .top, spacing: OceanSpacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(OceanTypography.body)
                    .foregroundStyle(OceanPalette.sand)
                    .accessibilityHidden(true)

                Text(advisory.warning)
                    .font(OceanTypography.body)
                    .foregroundStyle(OceanPalette.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let conditionsLine = advisory.conditionsLine {
                Text(conditionsLine)
                    .font(OceanTypography.caption)
                    .foregroundStyle(OceanPalette.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !advisory.notes.isEmpty {
                HStack(alignment: .top, spacing: OceanSpacing.xxs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(OceanTypography.smallLabel)
                        .foregroundStyle(OceanPalette.sand)
                        .accessibilityHidden(true)
                    Text(advisory.notes.joined(separator: " · "))
                        .font(OceanTypography.bodyEmphasized)
                        .foregroundStyle(OceanPalette.sand)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()
                .overlay(OceanPalette.white.opacity(0.2))

            Label(advisory.level.label, systemImage: advisory.level.symbolName)
                .font(OceanTypography.caption)
                .foregroundStyle(OceanPalette.swimmingRiskText(advisory.level))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(OceanSpacing.lg)
        .oceanGlassCard(cornerRadius: OceanGlass.answerCornerRadius)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(advisory.accessibilitySentence)
    }
}
