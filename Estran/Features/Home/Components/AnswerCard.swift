import EstranCore
import SwiftUI

/// The Home answer card: label, giant verdict, reason and context line.
///
/// Accessibility: the whole card is **one** element read as a sentence
/// (« Oui, pêche à pied, conditions réunies »), and the verdict always carries
/// a word plus an icon, so colour is never the only signal.
struct AnswerCard: View {
    let decision: GoDecision
    let activity: Activity
    let conditions: Conditions

    /// 76 pt at the default size, scaled by Dynamic Type. No clamp: the card
    /// lives in a `ScrollView`, so AX5 grows the layout instead of clipping it.
    @ScaledMetric(relativeTo: .largeTitle) private var badgeSize: CGFloat =
        OceanTypography.goBadgeBaseSize

    private var state: VerdictState {
        VerdictState(decision: decision)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.sm) {
            Text("BON MOMENT POUR SORTIR ?")
                .font(OceanTypography.smallLabel)
                .tracking(1.2)
                .foregroundStyle(OceanPalette.white.opacity(0.7))

            HStack(alignment: .center, spacing: OceanSpacing.sm) {
                Image(systemName: state.symbolName)
                    .font(.system(size: wordSize * 0.4, weight: .semibold))
                    .foregroundStyle(state.color)
                    .accessibilityHidden(true)

                Text(state.word)
                    .font(OceanTypography.rounded(size: wordSize))
                    .foregroundStyle(state.color)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(decision.reason)
                .font(OceanTypography.bodyEmphasized)
                .foregroundStyle(OceanPalette.white)
                .fixedSize(horizontal: false, vertical: true)

            if let detail {
                Text(detail)
                    .font(OceanTypography.subtitle)
                    .foregroundStyle(OceanPalette.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(OceanSpacing.lg)
        .oceanGlassCard(cornerRadius: OceanGlass.answerCornerRadius)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySentence)
    }

    /// « Indisponible » is a long word: it is displayed smaller than Oui/Non so
    /// it fits without shrinking the Dynamic Type scale of the rest.
    private var wordSize: CGFloat {
        state == .unavailable ? badgeSize * 0.5 : badgeSize
    }

    private var detail: String? {
        if state == .unavailable {
            // Say what it means for the user, not which validation step is
            // missing (early M3 review, v6 follow-up).
            if activity == .swimming {
                return "On ne peut pas encore te répondre pour la baignade ici — "
                    + "le modèle de courant n'est pas vérifié."
            }
            return "On ne peut pas encore te répondre ici — "
                + "les données nécessaires ne sont pas vérifiées."
        }
        // The coefficient is deliberately absent in v1: the Brest model is not
        // validated against a published Annuaire sample (review Z23). The layout
        // holds without it, and the reason line never truncates.
        guard let next = conditions.tide.next else { return nil }
        return "\(FrenchFormat.tideEventKind(next.kind)) à "
            + "\(FrenchFormat.time(next.time, in: conditions.spot.timezone))"
    }

    private var accessibilitySentence: String {
        switch state {
        case .go:
            var sentence = "Oui, \(activity.displayName), conditions réunies."
            if let detail {
                sentence += " \(detail)."
            }
            return sentence
        case .noGo:
            var sentence = "Non, \(activity.displayName). \(decision.reason)"
            if let detail {
                sentence += " \(detail)."
            }
            return sentence
        case .unavailable:
            return "Données indisponibles pour \(activity.displayName). "
                + (detail ?? "")
        }
    }
}
