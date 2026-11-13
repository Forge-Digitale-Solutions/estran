import EstranCore
import SwiftUI

/// 02 — Détail spot. Tide curve, metrics, the five activities, the alert opt-in.
///
/// Everything is derived from the **shared store**: the same `Conditions`,
/// forecast and `ActivityOverview` values the Home card and the map read. The
/// screen never calls an engine and never invents a value: a missing curve or a
/// missing measurement renders an explicit unavailable line.
///
/// The coefficient is absent by design (v1, review Z23) and the swimming row
/// shows a risk level, never a verdict (`AGENTS.md` invariant 1).
struct SpotDetailView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: OceanSpacing.lg) {
                    header
                    content
                    if case .ready = app.store.phase, app.store.conditions != nil {
                        AlertOptInToggle()
                            .padding(OceanSpacing.md)
                            .oceanGlassCard(cornerRadius: OceanGlass.cardCornerRadius)
                            .spotDetailScrollTransition(reduceMotion: reduceMotion)
                    }
                    attribution
                        .id("spot.detail.bottom")
                }
                .padding(.horizontal, OceanSpacing.md)
                .padding(.top, OceanSpacing.sm)
                .padding(.bottom, OceanSpacing.xxl)
            }
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            .background { OceanBackdrop() }
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("spot.detail")
            .task {
                guard ProcessInfo.processInfo.arguments.contains("-estranScrollDetailBottom")
                else { return }
                try? await Task.sleep(for: .milliseconds(600))
                proxy.scrollTo("spot.detail.bottom", anchor: .bottom)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
            if dynamicTypeSize.isAccessibilitySize {
                // The badge and a 3-line title cannot share a row at AX sizes:
                // the badge used to squeeze the title and wrap inside a word.
                VStack(alignment: .leading, spacing: OceanSpacing.xs) {
                    spotTitle
                    sampleBadge
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: OceanSpacing.xs) {
                    spotTitle
                    Spacer(minLength: 0)
                    sampleBadge
                }
            }
            Text(subtitle)
                .font(OceanTypography.subtitle)
                .foregroundStyle(OceanPalette.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var spotTitle: some View {
        Text(app.selectedSpot.name)
            .font(OceanTypography.largeTitle)
            .foregroundStyle(OceanPalette.white)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var sampleBadge: some View {
        if app.usesSampleData {
            SampleDataBadge()
        }
    }

    /// « Bassin d'Arcachon · lundi 26 oct. » — no coefficient (v1), and the date
    /// comes from the data, not from the device clock.
    private var subtitle: String {
        guard let conditions = app.store.conditions else {
            return FrenchFormat.regionName(app.selectedSpot.region)
        }
        let day = FrenchFormat.weekdayDate(
            conditions.at,
            in: app.selectedSpot.timezone)
        return "\(FrenchFormat.regionName(app.selectedSpot.region)) · \(day)"
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch app.store.phase {
        case .idle, .loading:
            LoadingDetailCard()
                .spotDetailScrollTransition(reduceMotion: reduceMotion)
        case let .unavailable(message):
            UnavailableDetailCard(message: message)
                .spotDetailScrollTransition(reduceMotion: reduceMotion)
        case .ready:
            if let conditions = app.store.conditions {
                TideChartCard(
                    curve: conditions.tide.curve,
                    events: conditions.tide.allEvents,
                    goodWindows: goodWindows,
                    nextEventLine: nextEventLine(conditions),
                    rangeLine: app.tideRangeLine(for: conditions),
                    windowLine: windowLine(conditions),
                    timeZone: app.selectedSpot.timezone,
                    now: conditions.at,
                    accessibilitySentence: chartSentence(conditions))
                    .spotDetailScrollTransition(reduceMotion: reduceMotion)
                metrics(conditions)
                    .spotDetailScrollTransition(reduceMotion: reduceMotion)
                ActivityOverviewList(
                    overviews: app.overviews,
                    timeZone: app.selectedSpot.timezone)
                    .spotDetailScrollTransition(reduceMotion: reduceMotion)
            } else {
                UnavailableDetailCard(message: "Les données sont indisponibles pour ce spot.")
                    .spotDetailScrollTransition(reduceMotion: reduceMotion)
            }
        }
    }

    private func metrics(_ conditions: Conditions) -> some View {
        HStack(alignment: .top, spacing: OceanSpacing.sm) {
            ConditionTile(
                icon: "wind",
                title: "Vent",
                value: FrenchFormat.windSpeed(conditions.weather.wind),
                label: "km/h \(FrenchFormat.windDirection(conditions.weather.wind))",
                spoken: "Vent : \(FrenchFormat.wind(conditions.weather.wind)), "
                    + "direction \(FrenchFormat.windDirection(conditions.weather.wind))")
            ConditionTile(
                icon: "water.waves",
                title: "Houle",
                value: FrenchFormat.swellHeight(conditions.swell),
                label: FrenchFormat.swellTileLabel(conditions.swell),
                spoken: "Houle\(conditions.swell.isEstimated ? " estimée à partir du vent" : "") : "
                    + "\(FrenchFormat.swellHeight(conditions.swell)), "
                    + "période \(FrenchFormat.swellPeriod(conditions.swell))")
            ConditionTile(
                icon: FrenchFormat.weatherSymbol(conditions.weather.condition),
                title: "Météo",
                value: FrenchFormat.temperature(conditions.weather.temperature),
                label: FrenchFormat.weatherLabel(conditions.weather.condition),
                spoken: "Météo : \(FrenchFormat.temperature(conditions.weather.temperature)), "
                    + FrenchFormat.weatherLabel(conditions.weather.condition))
        }
    }

    private var attribution: some View {
        Text("Source : REFMAR / Shom — Licence Ouverte 2.0 — modèle local non officiel.")
            .font(OceanTypography.smallLabel)
            .foregroundStyle(OceanPalette.white.opacity(0.6))
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Chart copy

    /// The good windows drawn on the curve: the current activity's, which is the
    /// one the detail screen is opened for. An unavailable activity draws none —
    /// a band would claim a window the engine refused to confirm.
    private var goodWindows: [DateInterval] {
        guard !app.unavailableActivities.contains(app.activity) else { return [] }
        return app.slots.map(\.window)
    }

    private func nextEventLine(_ conditions: Conditions) -> String? {
        guard let next = conditions.tide.next else { return nil }
        return "\(shortKind(next.kind)) "
            + "\(FrenchFormat.time(next.time, in: app.selectedSpot.timezone)) · "
            + "\(FrenchFormat.height(next.height)) m"
    }

    private func shortKind(_ kind: TideEvent.Kind) -> String {
        switch kind {
        case .high: "Haute"
        case .low: "Basse"
        }
    }

    private func windowLine(_ conditions: Conditions) -> String? {
        // A not-offered activity has no window, and an unavailable activity has
        // none to confirm either: no « Aucun créneau » line, which would read as
        // a verdict the spot cannot make.
        guard !app.isActivityNotOffered,
              !app.unavailableActivities.contains(app.activity)
        else { return nil }
        guard let slot = app.currentSlot ?? app.upcomingSlot else {
            return FrenchFormat.emptyWindowReason(app.emptyWindowBlocker)
                ?? "Aucun créneau dans les 48 prochaines heures."
        }
        // Name the activity: the curve and the bands belong to the activity
        // selected on Home, while the list below covers all five.
        return "Bon créneau \(app.activity.displayName.lowercased()) · "
            + FrenchFormat.range(slot.window, in: app.selectedSpot.timezone, reference: conditions.at)
    }

    /// Spoken value of the chart: the same two lines the card draws, plus the
    /// time of the marker. A chart whose shape is the only content is unreadable
    /// with VoiceOver, so the next event is always spoken.
    private func chartSentence(_ conditions: Conditions) -> String {
        var parts = ["Marée"]
        if let next = conditions.tide.next {
            let kind = next.kind == .high ? "Marée haute" : "Marée basse"
            parts.append(
                "\(kind) à \(FrenchFormat.time(next.time, in: app.selectedSpot.timezone)), "
                    + "\(FrenchFormat.height(next.height)) mètres")
        } else {
            parts.append("prochaine marée indisponible")
        }
        if let rangeLine {
            parts.append(rangeLine)
        }
        if let line = windowLine(conditions) {
            parts.append(line)
        }
        return parts.joined(separator: ". ") + "."
    }

    /// The day's marnage, or `nil` when the model cannot give it.
    private var rangeLine: String? {
        guard let conditions = app.store.conditions else { return nil }
        return app.tideRangeLine(for: conditions)
    }
}

// MARK: - Scroll choreography

private extension View {
    /// Subtle depth entrance on lower glass cards. Identity under Reduce Motion.
    @ViewBuilder
    func spotDetailScrollTransition(reduceMotion: Bool) -> some View {
        if reduceMotion {
            scrollTransition(.identity) { content, _ in content }
        } else {
            scrollTransition(.animated(.smooth)) { content, phase in
                content
                    .opacity(phase.isIdentity ? 1 : 0.88)
                    .scaleEffect(phase.isIdentity ? 1 : 0.97)
            }
        }
    }
}

private struct LoadingDetailCard: View {
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
        .oceanGlassCard(cornerRadius: OceanGlass.cardCornerRadius)
        .accessibilityElement(children: .combine)
    }
}

private struct UnavailableDetailCard: View {
    let message: String

    @ScaledMetric(relativeTo: .body) private var iconWellSize: CGFloat = 32

    private var iconWellSide: CGFloat {
        min(iconWellSize, 48)
    }

    var body: some View {
        HStack(alignment: .top, spacing: OceanSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(OceanTypography.body)
                .foregroundStyle(OceanPalette.unavailable)
                .frame(width: iconWellSide, height: iconWellSide)
                .oceanConcentricInset(minimumRadius: 10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: OceanSpacing.xs) {
                Text("Données indisponibles")
                    .font(OceanTypography.bodyEmphasized)
                    .foregroundStyle(OceanPalette.unavailable)
                Text(message)
                    .font(OceanTypography.caption)
                    .foregroundStyle(OceanPalette.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(OceanSpacing.lg)
        .oceanGlassCard(cornerRadius: OceanGlass.cardCornerRadius)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SpotDetailPreview()
}

private struct SpotDetailPreview: View {
    @State private var app = AppModel()

    var body: some View {
        NavigationStack {
            SpotDetailView()
        }
        .environment(app)
        .task { await app.reload() }
    }
}
