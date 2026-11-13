import SwiftUI

/// One word the screens use, and what it means.
///
/// The copy is French, tutoiement, short sentences: it explains the vocabulary
/// the app already shows (« marnage », « houle estimée », « créneau ») without
/// introducing a number or a promise the model cannot make. The coefficient
/// entry exists to say **why it is absent** (`AGENTS.md` invariant 6), and the
/// swimming entry repeats that it is a risk level, never a `Oui`
/// (invariant 1).
struct IndicatorGlossaryEntry: Identifiable {
    /// The term itself, which is also a stable identity.
    let term: String
    let detail: String

    var id: String {
        term
    }

    static let all: [IndicatorGlossaryEntry] = [
        IndicatorGlossaryEntry(
            term: "Marée",
            detail: "La hauteur d'eau au-dessus du zéro du port, à l'instant affiché. "
                + "Elle monte jusqu'à la pleine mer, puis descend jusqu'à la basse mer. "
                + "C'est un modèle local, pas une mesure."),
        IndicatorGlossaryEntry(
            term: "Marnage, grande et petite marée",
            detail: "Le marnage, c'est l'écart entre la basse mer et la haute mer du jour. "
                + "Grande marée : marnage dans le tiers le plus fort des marées de ce spot. "
                + "Marée moyenne : entre les deux. Petite marée : tiers le plus faible. "
                + "Ces seuils sont calculés localement, sur le modèle de ce spot."),
        IndicatorGlossaryEntry(
            term: "Houle",
            detail: "La hauteur des vagues et leur période, c'est-à-dire le temps entre deux "
                + "vagues. Sur la côte océane, elle vient du modèle Open-Meteo Marine. Dans le "
                + "Bassin, elle est estimée à partir du vent : elle est donc indicative. "
                + "« Calme » veut dire moins de 10 cm."),
        IndicatorGlossaryEntry(
            term: "Vent",
            detail: "La vitesse moyenne en km/h et la direction d'où il vient. "
                + "Les rafales peuvent être plus fortes que la vitesse affichée."),
        IndicatorGlossaryEntry(
            term: "Météo",
            detail: "La température de l'air, le ciel et le risque de pluie. Apple Météo "
                + "(WeatherKit) répond en premier ; Open-Meteo prend le relais quand Apple ne "
                + "répond pas. La source réellement utilisée est écrite sous les valeurs."),
        IndicatorGlossaryEntry(
            term: "Coefficient",
            detail: "Il n'est pas affiché. Le coefficient national, calculé à Brest, est bien "
                + "calculé ici mais il n'est pas validé : la baignade s'appuie sur le marnage "
                + "local prédit, pas sur lui."),
        IndicatorGlossaryEntry(
            term: "Baignade",
            detail: "Un niveau de courant, jamais un oui. Les baïnes et les courants sont "
                + "dangereux toute l'année, même quand la mer est belle."),
        IndicatorGlossaryEntry(
            term: "Créneau",
            detail: "Le prochain moment favorable dans les 48 h qui viennent : les conditions "
                + "y passent tous les critères de ton activité."),
        IndicatorGlossaryEntry(
            term: "Données indisponibles",
            detail: "Une donnée manque. L'app préfère ne rien affirmer plutôt qu'inventer une "
                + "valeur : regarde plus tard ou change de spot.")
    ]
}

/// One glossary row: the term as a heading, then its short explanation.
///
/// The heading trait is what lets VoiceOver's rotor jump from indicator to
/// indicator at AX5, where a single entry can fill the screen.
struct IndicatorGlossaryRow: View {
    let entry: IndicatorGlossaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
            Text(entry.term)
                .font(OceanTypography.bodyEmphasized)
                .foregroundStyle(OceanPalette.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(entry.detail)
                .font(OceanTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, OceanSpacing.xxs)
    }
}

#Preview {
    List {
        ForEach(IndicatorGlossaryEntry.all) { entry in
            IndicatorGlossaryRow(entry: entry)
        }
    }
    .scrollContentBackground(.hidden)
    .background { OceanBackdrop() }
}
