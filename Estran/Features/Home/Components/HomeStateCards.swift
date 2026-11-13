import EstranCore
import SwiftUI

// The three non-verdict states of the Home answer area.
//
// They live beside `HomeView` rather than inside it so the screen file stays
// readable; each one is a distinct, honest state and none of them is a verdict:
//
// - `LoadingCard` — data is being fetched, no value is shown yet;
// - `NotOfferedCard` — the spot does not offer the activity (surf inside the
//   Bassin): a neutral sentence, never a `Non`;
// - `UnavailableCard` — the data cannot answer: « Données indisponibles »,
//   never a fabricated `Non` (`AGENTS.md` invariant 4).

struct LoadingCard: View {
    var body: some View {
        HStack(spacing: OceanSpacing.sm) {
            ProgressView()
            Text("Chargement des conditions…")
                .font(OceanTypography.body)
                .foregroundStyle(OceanPalette.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(OceanSpacing.lg)
        .oceanGlassCard(cornerRadius: OceanGlass.answerCornerRadius)
        .accessibilityElement(children: .combine)
    }
}

/// An activity the spot does not offer (surf inside the Bassin). A distinct,
/// neutral state: never a `Non`, never « Données indisponibles » — the data can
/// answer, the spot simply does not offer the activity. The segmented control
/// above still lets the user pick another activity; the button switches spot.
struct NotOfferedCard: View {
    let activity: Activity
    let spot: Spot
    let onSwitchSpot: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.sm) {
            HStack(alignment: .top, spacing: OceanSpacing.xs) {
                Image(systemName: "figure.surfing")
                    .font(OceanTypography.body)
                    .foregroundStyle(OceanPalette.sand)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
                    Text(ActivityOffer.notOfferedTitle(activity: activity, spot: spot))
                        .font(OceanTypography.bodyEmphasized)
                        .foregroundStyle(OceanPalette.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail = ActivityOffer.notOfferedDetail(activity: activity) {
                        Text(detail)
                            .font(OceanTypography.subtitle)
                            .foregroundStyle(OceanPalette.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Button(action: onSwitchSpot) {
                HStack(spacing: OceanSpacing.xxs) {
                    Text("Changer de spot")
                        .font(OceanTypography.button)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.right")
                        .font(OceanTypography.smallLabel)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(OceanPalette.turquoiseOnGlass)
                .padding(.horizontal, OceanSpacing.sm)
                .padding(.vertical, OceanSpacing.xs)
                .frame(maxWidth: .infinity, minHeight: OceanGlass.minimumTapHeight)
                .oceanGlassCapsule(interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Ouvre la carte pour choisir un autre spot")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(OceanSpacing.lg)
        .oceanGlassCard(cornerRadius: OceanGlass.answerCornerRadius)
        .accessibilityElement(children: .combine)
    }
}

/// Visible unavailable state. It is not an error to hide: the card explains why
/// the data cannot answer, and the rest of the screen keeps working.
struct UnavailableCard: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.sm) {
            Text("BON MOMENT POUR SORTIR ?")
                .font(OceanTypography.smallLabel)
                .tracking(1.2)
                .foregroundStyle(OceanPalette.white.opacity(0.7))

            HStack(alignment: .center, spacing: OceanSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(OceanTypography.metricValue)
                    .foregroundStyle(OceanPalette.unavailable)
                    .accessibilityHidden(true)
                Text("Données indisponibles")
                    .font(OceanTypography.metricValue)
                    .foregroundStyle(OceanPalette.unavailable)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(message)
                .font(OceanTypography.subtitle)
                .foregroundStyle(OceanPalette.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(OceanSpacing.lg)
        .oceanGlassCard(cornerRadius: OceanGlass.answerCornerRadius)
        .accessibilityElement(children: .combine)
    }
}
