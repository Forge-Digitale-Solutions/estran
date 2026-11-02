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
struct SpotsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var camera: MapCameraPosition = .automatic
    @State private var showsDetail = false

    var body: some View {
        NavigationStack {
            map
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(isPresented: $showsDetail) {
                    SpotDetailView()
                        .toolbar(.hidden, for: .tabBar)
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

            VStack(spacing: OceanSpacing.sm) {
                spotCard
                SpotSwitcher(spots: SpotCatalog.v1, selection: app.selectedSpot) { spot in
                    Task { @MainActor in
                        await app.select(spot: spot)
                    }
                }
            }
            .padding(.horizontal, OceanSpacing.md)
            .padding(.bottom, OceanSpacing.md)
        }
        .background(OceanPalette.backgroundGradient.ignoresSafeArea())
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
                    reduceMotion: reduceMotion))
            {
                camera = target
            }
        }
    }

    private var spotCard: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xs) {
            Text(app.selectedSpot.name)
                .font(OceanTypography.bodyEmphasized)
                .foregroundStyle(OceanPalette.white)
                .fixedSize(horizontal: false, vertical: true)

            verdictLine

            // Swimming has no "good window": the risk badge and warning are the
            // presentation, never a favourable slot.
            if app.store.phase == .ready, app.activity != .swimming {
                if app.unavailableActivities.contains(app.activity) {
                    Text("Créneaux indisponibles")
                        .font(OceanTypography.caption)
                        .foregroundStyle(OceanPalette.unavailable)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let window = app.currentSlot?.window ?? app.upcomingSlot?.window {
                    Text(FrenchFormat.range(window, in: app.selectedSpot.timezone))
                        .font(OceanTypography.caption)
                        .foregroundStyle(OceanPalette.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(OceanSpacing.md)
        .oceanGlassCard(cornerRadius: OceanGlass.cardCornerRadius)
    }

    @ViewBuilder
    private var verdictLine: some View {
        switch app.store.phase {
        case .ready:
            if let decision = app.decision {
                if app.activity == .swimming {
                    let advisory = app.store.conditions.map {
                        SwimmingAdvisory(decision: decision, conditions: $0)
                    } ?? SwimmingAdvisory(
                        level: .unknown,
                        region: app.selectedSpot.region)
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
                            .foregroundStyle(OceanPalette.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    VerdictBadge(decision: decision)
                }
            }
        case let .unavailable(message):
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
        case .idle, .loading:
            ProgressView()
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
