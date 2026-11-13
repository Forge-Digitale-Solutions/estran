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
///
/// **Glass, not a system `List`.** Every other screen is `oceanGlassCard` over
/// `OceanBackdrop`; a grouped `List` drew its own `#1C1C1E` cards and grey
/// section headers under the same title, which read as a different app. The
/// screen is a `ScrollView` of glass cards so the settings surface follows
/// `GlassAppearance` too: Reduce Transparency fills `navyInk`, Increase Contrast
/// adds the 1.5 pt border. Section titles stay 11 pt captions outside the cards,
/// like the overline of the answer card.
struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            ScrollView {
                VStack(alignment: .leading, spacing: OceanSpacing.lg) {
                    activitySection

                    // The weather credit WeatherKit's terms require, and the
                    // Open-Meteo credit CC BY 4.0 requires when the fallback
                    // answered. It sits second on the screen: a reviewer — and a
                    // user — must find it without scrolling. The mark only
                    // appears for Apple: crediting Apple for Open-Meteo values
                    // would be a false attribution.
                    weatherSection

                    sourceSection
                    glossarySection
                    spotsSection
                    aboutSection
                }
                .padding(.horizontal, OceanSpacing.md)
                .padding(.top, OceanSpacing.xs)
                .padding(.bottom, OceanSpacing.xxl)
                .oceanReadableWidth()
            }
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

    // MARK: - Sections

    private var activitySection: some View {
        section("Ton activité") {
            Button {
                showsActivityPicker = true
            } label: {
                activityRow
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Activité")
            .accessibilityValue(app.activity.displayName)
            .accessibilityHint("Ouvre le choix de l'activité")
        }
    }

    @ViewBuilder
    private var activityRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
                activityName
                activityValue
            }
            .frame(maxWidth: .infinity, minHeight: OceanGlass.minimumTapHeight, alignment: .leading)
            .contentShape(Rectangle())
        } else {
            HStack(spacing: OceanSpacing.sm) {
                activityName
                Spacer(minLength: OceanSpacing.xs)
                activityValue
                disclosureGlyph
            }
            .frame(maxWidth: .infinity, minHeight: OceanGlass.minimumTapHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
    }

    private var activityName: some View {
        Text("Activité")
            .font(OceanTypography.body)
            .foregroundStyle(OceanPalette.white)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var activityValue: some View {
        Text(app.activity.displayName)
            .font(OceanTypography.body)
            .foregroundStyle(OceanPalette.white.opacity(0.7))
            .multilineTextAlignment(.trailing)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var disclosureGlyph: some View {
        Image(systemName: "chevron.right")
            .font(OceanTypography.smallLabel)
            .foregroundStyle(OceanPalette.white.opacity(0.5))
            .accessibilityHidden(true)
    }

    private var weatherSection: some View {
        section("Météo") {
            VStack(alignment: .leading, spacing: OceanSpacing.xs) {
                if app.usesSampleData {
                    Text("Données d'exemple : aucune source météo réelle n'est affichée.")
                        .settingsFootnote()
                } else {
                    WeatherAttributionFooter(spotID: app.selectedSpot.id, store: weather)
                }
                SettingsDivider()
                Text(
                    "Apple Météo (WeatherKit) répond en premier ; Open-Meteo prend "
                        + "le relais quand Apple ne répond pas.")
                    .settingsFootnote()
            }
        }
    }

    private var sourceSection: some View {
        section("Source des données") {
            VStack(alignment: .leading, spacing: 0) {
                SettingsValueRow(label: "Producteur", value: "REFMAR / Shom")
                SettingsDivider()
                SettingsValueRow(label: "Licence", value: "Licence Ouverte 2.0")
                SettingsDivider()
                SettingsValueRow(label: "Mise à jour", value: Self.sourceLastUpdate)
                SettingsDivider()
                licenceButton
            }
            Text(
                "Modèle harmonique local calculé à partir des observations "
                    + "REFMAR. Il n'est pas officiel et ne remplace pas les "
                    + "documents officiels.")
                .settingsFootnote()
        }
    }

    /// A text link with the HIG's 44 pt tap height: the licence is a legal
    /// destination, not decoration.
    private var licenceButton: some View {
        Button {
            if let url = Self.licenceURL {
                openURL(url)
            }
        } label: {
            HStack(spacing: OceanSpacing.xxs) {
                Text("Voir la licence")
                    .font(OceanTypography.button)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "arrow.up.right")
                    .font(OceanTypography.smallLabel)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(OceanPalette.turquoiseOnGlass)
            .frame(maxWidth: .infinity, minHeight: OceanGlass.minimumTapHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Ouvre la licence dans le navigateur")
    }

    private var glossarySection: some View {
        section("Comprendre les indicateurs") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(IndicatorGlossaryEntry.all.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 {
                        SettingsDivider()
                    }
                    IndicatorGlossaryRow(entry: entry)
                }
            }
        }
    }

    private var spotsSection: some View {
        section("Spots") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(SpotCatalog.v1.enumerated()), id: \.element.id) { index, spot in
                    if index > 0 {
                        SettingsDivider()
                    }
                    spotRow(spot)
                }
            }
        }
    }

    private func spotRow(_ spot: Spot) -> some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
            Text(spot.name)
                .font(OceanTypography.body)
                .foregroundStyle(OceanPalette.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(spot.modelLabel)
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, OceanSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    private var aboutSection: some View {
        section("À propos") {
            SettingsValueRow(label: "Version", value: Self.version)
            SettingsDivider()
            Text(
                "Estran — conditions de sortie en mer sur le Bassin "
                    + "d'Arcachon et le Médoc.")
                .settingsFootnote()
        }
    }

    // MARK: - Section shell

    /// A caption title and one glass card, the shape every app screen uses.
    /// Section titles are outside the card, so they stay a reading cue and
    /// never look like a row.
    private func section(
        _ title: String,
        @ViewBuilder content: () -> some View) -> some View
    {
        VStack(alignment: .leading, spacing: OceanSpacing.xs) {
            Text(title)
                .font(OceanTypography.smallLabel)
                .tracking(1.2)
                .foregroundStyle(OceanPalette.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: OceanSpacing.xs) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(OceanSpacing.md)
            .oceanGlassCard(cornerRadius: OceanGlass.cardCornerRadius)
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

// MARK: - Rows

/// One label/value line inside a settings card. At accessibility sizes the pair
/// stacks: a value squeezed into a trailing column wraps into a three-word
/// ribbon, which is the failure `DESIGN_REFERENCE.md` §2.1 forbids.
private struct SettingsValueRow: View {
    let label: String
    let value: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
                    labelText
                    valueText
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: OceanSpacing.sm) {
                    labelText
                    Spacer(minLength: OceanSpacing.xs)
                    valueText
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, OceanSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    private var labelText: some View {
        Text(label)
            .font(OceanTypography.body)
            .foregroundStyle(OceanPalette.white)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var valueText: some View {
        Text(value)
            .font(OceanTypography.body)
            .foregroundStyle(OceanPalette.white.opacity(0.7))
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Hairline between two rows of the same card. `Divider` draws the system
/// separator colour, which is a grey that does not exist in the palette.
private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(OceanPalette.white.opacity(0.12))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

private extension View {
    /// Secondary explanation inside a settings card: the small label at 70 %
    /// white, the same weight Home uses under its cards.
    func settingsFootnote() -> some View {
        font(OceanTypography.smallLabel)
            .foregroundStyle(OceanPalette.white.opacity(0.7))
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    SettingsPreview()
}

private struct SettingsPreview: View {
    @State private var app = AppModel()

    var body: some View {
        SettingsView()
            .environment(app)
            .task { await app.reload() }
    }
}
