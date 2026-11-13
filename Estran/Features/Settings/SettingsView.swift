import EstranCore
import SwiftUI

/// 06 — Réglages: attribution, the indicator glossary, spot labels, about.
///
/// The tide attribution is a legal requirement of Licence Ouverte 2.0, the
/// weather credit is a requirement of WeatherKit's terms (Apple Weather mark +
/// legal page) and of Open-Meteo's CC BY 4.0 licence, and the « non officiel »
/// statement is a product requirement: the model is our own harmonic fit, not a
/// SHOM prediction. The glossary says what the indicators mean, including why
/// the coefficient is absent.
struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(AppModel.self) private var app

    @State private var showsActivityPicker = false

    /// The weather credit follows the source that actually answered for the
    /// selected spot (`FallbackWeatherSource`), never the intent.
    private var weather: WeatherAttributionStore {
        .shared
    }

    private static let licenceURL =
        URL(string: "https://github.com/etalab/licence-ouverte/blob/master/LO.md")

    var body: some View {
        NavigationStack {
            List {
                Section("Ton activité") {
                    Button {
                        showsActivityPicker = true
                    } label: {
                        HStack(spacing: OceanSpacing.sm) {
                            Text("Activité")
                                .foregroundStyle(OceanPalette.white)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: OceanSpacing.xs)
                            Text(app.activity.displayName)
                                .foregroundStyle(OceanPalette.white.opacity(0.7))
                                .multilineTextAlignment(.trailing)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Activité")
                    .accessibilityValue(app.activity.displayName)
                }

                // The weather credit WeatherKit's terms require, and the
                // Open-Meteo credit CC BY 4.0 requires when the fallback
                // answered. It sits second on the screen: a reviewer — and a
                // user — must find it without scrolling. The mark only appears
                // for Apple: crediting Apple for Open-Meteo values would be a
                // false attribution.
                Section("Météo") {
                    if app.usesSampleData {
                        Text("Données d'exemple : aucune source météo réelle n'est affichée.")
                            .font(OceanTypography.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        WeatherAttributionFooter(spotID: app.selectedSpot.id, store: weather)
                    }
                    Text(
                        "Apple Météo (WeatherKit) répond en premier ; Open-Meteo prend "
                            + "le relais quand Apple ne répond pas.")
                        .font(OceanTypography.caption)
                        .foregroundStyle(.secondary)
                }

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

                Section("Comprendre les indicateurs") {
                    ForEach(IndicatorGlossaryEntry.all) { entry in
                        IndicatorGlossaryRow(entry: entry)
                    }
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
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            .background { OceanBackdrop() }
            .navigationTitle("Réglages")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .fullScreenCover(isPresented: $showsActivityPicker) {
                ActivityPickerView(
                    spotName: app.selectedSpot.name,
                    overviews: app.overviews,
                    selection: app.activity,
                    timeZone: app.selectedSpot.timezone,
                    onSelect: { app.select(activity: $0) })
            }
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
