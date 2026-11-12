import EstranCore
import SwiftUI

/// « Prochain bon créneau » card.
///
/// It shows the window in progress when the verdict is `Oui`, otherwise the
/// next one. With no window in the 48 h horizon it says so plainly — no
/// « bientôt », no invented time.
///
/// **Unavailable ≠ no window** (early M3 review, point 4): when the activity
/// cannot be answered because data is missing, the card says « Créneaux
/// indisponibles », never « Aucun créneau ». The sea is not the reason.
struct NextWindowCard: View {
    let current: ActivitySlot?
    let upcoming: ActivitySlot?
    let isUnavailable: Bool
    /// Why there is no window in the 48 h horizon, or `nil` to keep the generic
    /// sentence.
    let noWindowReason: String?
    let timeZone: TimeZone
    let reference: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var iconWellSize: CGFloat = 32

    private var iconWellSide: CGFloat {
        min(iconWellSize, 48)
    }

    var body: some View {
        HStack(alignment: .top, spacing: OceanSpacing.sm) {
            Image(systemName: isUnavailable ? "exclamationmark.triangle" : "clock")
                .font(OceanTypography.body)
                .foregroundStyle(isUnavailable ? OceanPalette.unavailable : OceanPalette.sand)
                .frame(width: iconWellSide, height: iconWellSide)
                .oceanConcentricInset(minimumRadius: 10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: OceanSpacing.xs) {
                Text(headline)
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(isUnavailable ? OceanPalette.unavailable : OceanPalette.sand)
                    .fixedSize(horizontal: false, vertical: true)

                if isUnavailable {
                    Text("Les données nécessaires ne sont pas disponibles pour cette activité.")
                        .font(OceanTypography.body)
                        .foregroundStyle(OceanPalette.white)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let primary {
                    windowText(primary)
                        .font(OceanTypography.bodyEmphasized)
                        .foregroundStyle(OceanPalette.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .animation(windowAnimation(primary), value: primary)
                } else {
                    Text(noWindowReason ?? "Aucun créneau dans les 48 prochaines heures.")
                        .font(OceanTypography.body)
                        .foregroundStyle(OceanPalette.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !isUnavailable, let secondary {
                    windowText(secondary)
                        .font(OceanTypography.caption)
                        .foregroundStyle(OceanPalette.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                        .animation(windowAnimation(secondary), value: secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(OceanSpacing.md)
        .oceanGlassCard(cornerRadius: OceanGlass.cardCornerRadius)
        .accessibilityElement(children: .combine)
    }

    /// A window is a pair of clock times: the digits roll when the window moves,
    /// which reads as a time change rather than a jump cut. Reduce Motion passes
    /// `nil` and the text lands on the new frame directly.
    private func windowText(_ text: String) -> some View {
        Text(text)
            .contentTransition(.numericText())
    }

    private func windowAnimation(_ text: String) -> Animation? {
        guard text.contains(where: \.isNumber) else { return nil }
        return OceanGlass.animation(
            .spring(response: 0.38, dampingFraction: 0.9),
            reduceMotion: reduceMotion)
    }

    private var headline: String {
        if isUnavailable {
            return "Créneaux indisponibles"
        }
        if current != nil {
            return "Créneau en cours"
        }
        if upcoming != nil {
            return "Prochain bon créneau"
        }
        return "Créneaux"
    }

    private var primary: String? {
        guard let slot = current ?? upcoming else { return nil }
        return FrenchFormat.range(slot.window, in: timeZone, reference: reference)
    }

    private var secondary: String? {
        guard current != nil, let slot = upcoming else { return nil }
        return "Puis \(FrenchFormat.range(slot.window, in: timeZone, reference: reference))"
    }
}
