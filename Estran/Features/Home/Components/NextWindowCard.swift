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
    let timeZone: TimeZone
    let reference: Date

    var body: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xs) {
            Label(headline, systemImage: isUnavailable ? "exclamationmark.triangle" : "clock")
                .font(OceanTypography.smallLabel)
                .foregroundStyle(isUnavailable ? OceanPalette.unavailable : OceanPalette.sand)

            if isUnavailable {
                Text("Les données nécessaires ne sont pas disponibles pour cette activité.")
                    .font(OceanTypography.body)
                    .foregroundStyle(OceanPalette.white)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let primary {
                Text(primary)
                    .font(OceanTypography.bodyEmphasized)
                    .foregroundStyle(OceanPalette.white)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Aucun créneau dans les 48 prochaines heures.")
                    .font(OceanTypography.body)
                    .foregroundStyle(OceanPalette.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !isUnavailable, let secondary {
                Text(secondary)
                    .font(OceanTypography.caption)
                    .foregroundStyle(OceanPalette.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(OceanSpacing.md)
        .oceanGlassCard(cornerRadius: OceanGlass.cardCornerRadius)
        .accessibilityElement(children: .combine)
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
        return FrenchFormat.range(slot.window, in: timeZone)
    }

    private var secondary: String? {
        guard current != nil, let slot = upcoming else { return nil }
        let range = FrenchFormat.range(slot.window, in: timeZone)
        if let day = FrenchFormat.relativeDay(
            slot.window.start, in: timeZone, reference: reference)
        {
            return "Puis \(day), \(range)"
        }
        return "Puis \(range)"
    }
}
