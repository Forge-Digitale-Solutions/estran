import EstranCore
import Foundation
import SwiftUI

/// The Home answer card: label, giant verdict, reason and context line.
///
/// Accessibility: the whole card is **one** element read as a sentence
/// (« Oui, pêche à pied. Marée basse à 14 h 12. »), and the verdict always
/// carries a word plus an icon, so colour is never the only signal.
struct AnswerCard: View {
    let decision: GoDecision
    let activity: Activity
    let conditions: Conditions
    /// The generated sentence for this decision, or `nil` while the on-device
    /// model has not answered. It only ever replaces the reason line, never the
    /// verdict.
    let refinedReason: String?

    /// 76 pt at the default size, scaled by Dynamic Type. No clamp: the card
    /// lives in a `ScrollView`, so AX5 grows the layout instead of clipping it.
    @ScaledMetric(relativeTo: .largeTitle) private var badgeSize: CGFloat =
        OceanTypography.goBadgeBaseSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var state: VerdictState {
        VerdictState(decision: decision)
    }

    var body: some View {
        VStack(alignment: .center, spacing: OceanSpacing.sm) {
            Text("BON MOMENT POUR SORTIR ?")
                .font(OceanTypography.smallLabel)
                .tracking(1.2)
                .foregroundStyle(OceanPalette.white.opacity(0.7))
                .multilineTextAlignment(.center)

            HStack(alignment: .center, spacing: OceanSpacing.sm) {
                Image(systemName: state.symbolName)
                    .font(.system(size: wordSize * 0.4, weight: .semibold))
                    .foregroundStyle(state.color)
                    .modifier(VerdictSymbolMotion(value: state, reduceMotion: reduceMotion))
                    .accessibilityHidden(true)

                Text(state.word)
                    .font(OceanTypography.rounded(size: wordSize))
                    .foregroundStyle(state.color)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(displayedReason)
                .font(OceanTypography.bodyEmphasized)
                .foregroundStyle(OceanPalette.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let caution {
                HStack(alignment: .top, spacing: OceanSpacing.xxs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(OceanTypography.smallLabel)
                        .foregroundStyle(OceanPalette.sand)
                        .accessibilityHidden(true)
                    Text(caution)
                        .font(OceanTypography.caption)
                        .foregroundStyle(OceanPalette.sand)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let detail {
                Text(detail)
                    .font(OceanTypography.subtitle)
                    .foregroundStyle(OceanPalette.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, OceanSpacing.sm)
                    .padding(.vertical, OceanSpacing.xs)
                    .frame(maxWidth: .infinity)
                    .oceanConcentricInset(minimumRadius: 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(OceanSpacing.lg)
        .oceanGlassCard(cornerRadius: OceanGlass.answerCornerRadius)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySentence)
    }

    /// The reason line the card draws, and the only string VoiceOver may read
    /// for it: one property, so a generated sentence can never diverge from the
    /// spoken one (VoiceOver audit F1).
    var displayedReason: String {
        if let refinedReason {
            let sentence = refinedReason.trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                return sentence
            }
        }
        // The template stays until a valid refined sentence exists: never an
        // empty line, never a placeholder.
        return decision.reason
    }

    /// Every caution this verdict carries: the conditional night/rain reminder
    /// plus the permanent spot caution (the Bassin passes), or `nil`. Copy only:
    /// it never changes the verdict.
    private var caution: String? {
        ActivityCaution.combined(decision)
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
            // Speak exactly the line the card draws, the way `.noGo` does: the
            // reason is part of the answer, not a decorative subtitle.
            var sentence = "Oui, \(activity.displayName). \(displayedReason)"
            if let caution {
                sentence += " \(caution)."
            }
            if let detail {
                sentence += " \(detail)."
            }
            return sentence
        case .noGo:
            var sentence = "Non, \(activity.displayName). \(displayedReason)"
            if let caution {
                sentence += " \(caution)."
            }
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

// MARK: - Verdict motion

/// Glyph motion for a verdict change (`docs/design/ios27-opportunities.md`,
/// item 4).
///
/// The `checkmark` / `xmark` / `triangle` is replaced by the system morph and
/// bounces once on the new state; the word beside it changes word, not symbol,
/// so nothing else is animated. Under Reduce Motion nothing is applied: the
/// glyph swaps instantly, exactly as a still frame would show it.
private struct VerdictSymbolMotion: ViewModifier {
    let value: VerdictState
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: value)
        }
    }
}
