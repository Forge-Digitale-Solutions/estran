import EstranCore
import SwiftUI

/// « Données d'exemple » — prototype artifact.
///
/// It is only ever rendered when the active provider reports `isSampleData`,
/// which is impossible in release: the demo provider is compiled under
/// `#if DEBUG`. The badge is a label, never a data path.
struct SampleDataBadge: View {
    var body: some View {
        Text("Données d'exemple")
            .font(OceanTypography.smallLabel)
            .foregroundStyle(OceanPalette.ink)
            .padding(.horizontal, OceanSpacing.xs)
            .padding(.vertical, OceanSpacing.xxs)
            .background(OceanPalette.sand, in: Capsule(style: .continuous))
            .accessibilityLabel("Données d'exemple")
    }
}

/// Compact glass pill showing the selected spot. Tapping it opens the focus map,
/// which is the only place a spot is chosen (`DESIGN_REFERENCE.md` §6.1).
struct SpotButton: View {
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: OceanSpacing.xxs) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(OceanPalette.turquoise)
                Text(name)
                    .font(OceanTypography.button)
                    .foregroundStyle(OceanPalette.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, OceanSpacing.sm)
            .padding(.vertical, OceanSpacing.xs)
            .frame(minHeight: OceanGlass.minimumTapHeight)
        }
        .buttonStyle(.glass)
        .accessibilityLabel("Spot : \(name)")
        .accessibilityHint("Ouvre la carte pour changer de spot")
    }
}

/// Compact verdict, used outside the Home answer card (focus map).
struct VerdictBadge: View {
    let decision: GoDecision

    var body: some View {
        let state = VerdictState(decision: decision)
        Label(state.word, systemImage: state.symbolName)
            .font(OceanTypography.button)
            .foregroundStyle(state.badgeColor)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Compact swimming level, used on the focus map. It never shows « Oui » and
/// never uses the green verdict colour.
struct SwimmingRiskBadge: View {
    let level: SwimmingRiskLevel

    var body: some View {
        Label(level.label, systemImage: "exclamationmark.triangle.fill")
            .font(OceanTypography.button)
            .foregroundStyle(OceanPalette.swimmingRiskText(level))
            .fixedSize(horizontal: false, vertical: true)
    }
}
