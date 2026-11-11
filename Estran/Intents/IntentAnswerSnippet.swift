import EstranCore
import SwiftUI

/// Compact Siri / Shortcuts snippet: same wording as `IntentAnswer`, glass card.
///
/// Uses `oceanGlassCard` so Reduce Transparency and Increase Contrast keep the
/// audited looks. Never shows « Oui » for swimming — the dialog text already
/// carries the risk level and the year-round warning.
struct IntentAnswerSnippet: View {
    let text: String
    let snapshot: WidgetSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.sm) {
            header
            Text(text)
                .font(OceanTypography.body)
                .foregroundStyle(OceanPalette.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(text)
        }
        .padding(OceanSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .oceanGlassCard()
        .padding(OceanSpacing.sm)
        .background { OceanBackdrop() }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var header: some View {
        if let snapshot {
            Label(snapshot.spotName, systemImage: snapshot.activity.symbolName)
                .font(OceanTypography.caption)
                .foregroundStyle(OceanPalette.turquoiseOnGlass)
                .labelStyle(.titleAndIcon)
                .accessibilityHidden(true)
        } else {
            Label("Estran", systemImage: "water.waves")
                .font(OceanTypography.caption)
                .foregroundStyle(OceanPalette.turquoiseOnGlass)
                .accessibilityHidden(true)
        }
    }
}
