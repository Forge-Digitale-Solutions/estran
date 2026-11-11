import EstranCore
import MapKit
import SwiftUI

/// 05 — Carte focus. Two spots, one marker, no browsing.
///
/// The map is deliberately **not** interactive: free panning across the 90 km
/// between the two spots would turn it into a browsing map. The camera animates
/// between two fixed framings, and `SpotSwitcher` is the only selector. Under
/// Reduce Motion the camera still moves to the new spot, but it does not slide
/// across the 90 km: `OceanGlass.animation(_:reduceMotion:)` returns `nil`, so
/// the framing is applied at once.
///
/// The map is drawn edge to edge with its own colours: no
/// `backgroundExtensionEffect()` (it mirrors and blurs the raster into the safe
/// areas, which washed the whole top of the screen with the land's green), and
/// the card is the only glass over the tiles.
struct SpotsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityPrefersCrossFadeTransitions) private var prefersCrossFade

    @Namespace private var detailTransitionNamespace
    @State private var camera: MapCameraPosition = .automatic
    @State private var showsDetail = false

    private var usesCrossFadeTransition: Bool {
        reduceMotion || prefersCrossFade
    }

    var body: some View {
        NavigationStack {
            map
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(isPresented: $showsDetail) {
                    SpotDetailView()
                        .toolbar(.hidden, for: .tabBar)
                        .navigationTransition(
                            usesCrossFadeTransition
                                ? AnyNavigationTransition(.crossFade)
                                : AnyNavigationTransition(
                                    .zoom(
                                        sourceID: app.selectedSpot.id,
                                        in: detailTransitionNamespace)))
                }
        }
    }

    private var map: some View {
        ZStack(alignment: .bottom) {
            Map(position: $camera, interactionModes: []) {
                Marker(
                    app.selectedSpot.name,
                    coordinate: coordinate(app.selectedSpot))
                    .tint(OceanPalette.turquoise)
            }
            .mapStyle(
                .standard(
                    elevation: .flat,
                    pointsOfInterest: .excludingAll,
                    showsTraffic: false))
            .ignoresSafeArea()

            GlassEffectContainer(spacing: OceanSpacing.sm) {
                VStack(spacing: OceanSpacing.sm) {
                    spotCard
                    SpotSwitcher(spots: SpotCatalog.v1, selection: app.selectedSpot) { spot in
                        Task { @MainActor in
                            await app.select(spot: spot)
                        }
                    }
                }
            }
            .padding(.horizontal, OceanSpacing.md)
            .padding(.bottom, OceanSpacing.md)
        }
        .background { OceanBackdrop() }
        .onAppear {
            camera = position(for: app.selectedSpot)
        }
        .onChange(of: app.selectedSpot.id) { _, _ in
            let target = position(for: app.selectedSpot)
            // `withAnimation(nil)` applies the new framing without moving the
            // camera across the Bassin, which is what Reduce Motion asks for.
            withAnimation(
                OceanGlass.animation(
                    .spring(response: 0.55, dampingFraction: 0.85),
                    reduceMotion: reduceMotion || prefersCrossFade))
            {
                camera = target
            }
        }
    }

    /// The one data path: the store's loaded conditions and the engine's
    /// decision, read through `AppModel`. Nothing is cached in the view, so a
    /// spot switch can never paint an expired window.
    private var cardSummary: SpotCardSummary? {
        SpotCardSummary(from: app)
    }

    private var spotCard: some View {
        let summary = cardSummary
        return VStack(alignment: .leading, spacing: OceanSpacing.xs) {
            Text(app.selectedSpot.name)
                .font(OceanTypography.bodyEmphasized)
                .foregroundStyle(OceanPalette.white)
                .fixedSize(horizontal: false, vertical: true)

            verdictLine(summary: summary)

            // Swimming has no "good window": the risk badge and warning are the
            // presentation, never a favourable slot.
            if let summary, app.activity != .swimming {
                if summary.isActivityUnavailable {
                    Text("Créneaux indisponibles")
                        .font(OceanTypography.caption)
                        .foregroundStyle(OceanPalette.unavailable)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let window = summary.window {
                    Text(FrenchFormat.range(window, in: app.selectedSpot.timezone))
                        .font(OceanTypography.caption)
                        .foregroundStyle(OceanPalette.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            detailButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(OceanSpacing.md)
        .oceanGlassCard(cornerRadius: OceanGlass.cardCornerRadius, permanentBacking: true)
        .matchedTransitionSource(id: app.selectedSpot.id, in: detailTransitionNamespace)
    }

    private var detailButton: some View {
        // The detail screen is where the chart, the five activities and the
        // alert opt-in live; the card stays a summary.
        Button {
            showsDetail = true
        } label: {
            HStack(spacing: OceanSpacing.xxs) {
                Text("Voir le détail")
                    .font(OceanTypography.button)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.right")
                    .font(OceanTypography.smallLabel)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(OceanPalette.turquoiseOnGlass)
            .frame(maxWidth: .infinity, minHeight: OceanGlass.minimumTapHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Ouvre la courbe de marée et les cinq activités")
    }

    @ViewBuilder
    private func verdictLine(summary: SpotCardSummary?) -> some View {
        if let summary {
            if app.activity == .swimming {
                swimmingSummaryView(
                    SwimmingAdvisory(
                        decision: summary.decision,
                        conditions: summary.conditions))
            } else {
                VerdictBadge(decision: summary.decision)
            }
        } else {
            switch app.store.phase {
            case let .unavailable(message):
                unavailableVerdictView(message: message)
            case .idle, .loading, .ready:
                // A spot switch clears the store before it reloads: the card
                // says it is working, never the previous spot's verdict.
                loadingVerdictView
            }
        }
    }

    /// The neutral state while the new spot loads. It shows no value at all,
    /// which is the only honest answer before the data exists (`AGENTS.md`
    /// invariants 3 and 4).
    private var loadingVerdictView: some View {
        HStack(spacing: OceanSpacing.xs) {
            ProgressView()
                .controlSize(.small)
            Text("Chargement…")
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chargement des conditions")
    }

    private func swimmingSummaryView(_ advisory: SwimmingAdvisory) -> some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
            Text(advisory.level.widgetWarning(for: advisory.region))
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white)
                .fixedSize(horizontal: false, vertical: true)
            if let line = advisory.conditionsLine {
                Text(line)
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !advisory.notes.isEmpty {
                Text(advisory.notes.joined(separator: " · "))
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.sand)
                    .fixedSize(horizontal: false, vertical: true)
            }
            SwimmingRiskBadge(level: advisory.level)
            Text(SwimmingRiskLevel.disclaimer)
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func unavailableVerdictView(message: String) -> some View {
        if app.activity == .swimming {
            VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
                Text(SwimmingRiskLevel.unknown.warning(for: app.selectedSpot.region))
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.white)
                    .fixedSize(horizontal: false, vertical: true)
                SwimmingRiskBadge(level: .unknown)
            }
        } else {
            VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
                Label("Données indisponibles", systemImage: "exclamationmark.triangle.fill")
                    .font(OceanTypography.button)
                    .foregroundStyle(OceanPalette.unavailable)
                Text(message)
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func coordinate(_ spot: Spot) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: spot.coordinate.latitude,
            longitude: spot.coordinate.longitude)
    }

    private func position(for spot: Spot) -> MapCameraPosition {
        .region(
            MKCoordinateRegion(
                center: coordinate(spot),
                span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)))
    }
}

/// The card's three lines, read once from the shared store.
///
/// It is a projection of `AppModel` and nothing else: no provider call, no
/// engine call, no retained copy that could outlive the conditions it describes.
private struct SpotCardSummary {
    let conditions: Conditions
    let decision: GoDecision
    let window: DateInterval?
    let isActivityUnavailable: Bool

    @MainActor
    init?(from app: AppModel) {
        guard app.store.phase == .ready,
              let conditions = app.store.conditions,
              conditions.spot.id == app.selectedSpot.id,
              let decision = app.decision
        else { return nil }

        self.conditions = conditions
        self.decision = decision
        window = (app.currentSlot ?? app.upcomingSlot)?.window
        isActivityUnavailable = app.unavailableActivities.contains(app.activity)
    }
}

#Preview {
    SpotsPreview()
}

private struct SpotsPreview: View {
    @State private var app = AppModel()

    var body: some View {
        SpotsView()
            .environment(app)
            .task { await app.reload() }
    }
}
