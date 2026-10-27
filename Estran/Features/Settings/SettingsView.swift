import EstranCore
import SwiftUI

/// 06 — Réglages: attribution, spot labels, about.
///
/// The attribution is a legal requirement of Licence Ouverte 2.0, and the
/// « non officiel » statement is a product requirement: the model is our own
/// harmonic fit, not a SHOM prediction.
struct SettingsView: View {
    @Environment(\.openURL) private var openURL

    private static let licenceURL =
        URL(string: "https://github.com/etalab/licence-ouverte/blob/master/LO.md")

    var body: some View {
        NavigationStack {
            List {
                Section("Source des données") {
                    LabeledContent("Producteur", value: "REFMAR / Shom")
                    LabeledContent("Licence", value: "Licence Ouverte 2.0")
                    LabeledContent("Mise à jour", value: Self.sourceLastUpdate)
                    if let url = Self.licenceURL {
                        Button("Voir la licence") {
                            openURL(url)
                        }
                    }
                    Text(
                        "Modèle harmonique local calculé à partir des observations "
                            + "REFMAR. Il n'est pas officiel et ne remplace pas les "
                            + "documents officiels.")
                        .font(OceanTypography.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Spots") {
                    ForEach(SpotCatalog.v1) { spot in
                        VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
                            Text(spot.name)
                            Text(spot.modelLabel)
                                .font(OceanTypography.smallLabel)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("À propos") {
                    LabeledContent("Version", value: Self.version)
                    Text(
                        "Estran — conditions de sortie en mer sur le Bassin "
                            + "d'Arcachon et le Médoc.")
                        .font(OceanTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(OceanPalette.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Réglages")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private static var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        return "\(short ?? "0.1") (\(build ?? "1"))"
    }

    /// Source last-update date read from the embedded dataset, never hard-coded.
    private static let sourceLastUpdate: String = {
        guard let model = try? ShippedTideModel.load(),
              let raw = model.sourceLastUpdate,
              let formatted = FrenchFormat.longDate(fromISO: raw)
        else {
            return "—"
        }
        return formatted
    }()
}

#Preview {
    SettingsView()
}
