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
    @Environment(\.accessibilityPrefersCrossFadeTransitions) private var prefersCrossFade

    @Namespace private var detailTransitionNamespace
    @State private var camera: MapCameraPosition = .automatic
    @State private var showsDetail = false
    @State private var cachedSummaries: [String: SpotCardSummary] = [:]

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
            .backgroundExtensionEffect()
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
            cacheCurrentSpotSummaryIfReady()
        }
        .task(id: app.activity) {
            cacheCurrentSpotSummaryIfReady()
            await prewarmSummaries(for: app.activity)
        }
        .onChange(of: app.store.phase) { _, _ in
            cacheCurrentSpotSummaryIfReady()
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

    private var activeSummary: SpotCardSummary? {
        if let live = SpotCardSummary(from: app) {
            return live
        }
        if let cached = cachedSummaries[app.selectedSpot.id],
           cached.spotID == app.selectedSpot.id,
           cached.activity == app.activity
        {
            return cached
        }
        return nil
    }

    private var spotCard: some View {
        let summary = activeSummary
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
                ProgressView()
            }
        }
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

    @MainActor
    private func cacheCurrentSpotSummaryIfReady() {
        guard let summary = SpotCardSummary(from: app) else { return }
        cachedSummaries[summary.spotID] = summary
    }

    @MainActor
    private func prewarmSummaries(for activity: Activity) async {
        let now = Date()
        for spot in SpotCatalog.v1 {
            guard !Task.isCancelled else { return }
            if let existing = cachedSummaries[spot.id],
               existing.activity == activity,
               existing.window != nil
            {
                continue
            }
            if let loaded = await SpotCardSummary.load(
                spot: spot,
                activity: activity,
                provider: app.provider,
                engine: app.engine,
                now: now)
            {
                cachedSummaries[spot.id] = loaded
            } else {
                cachedSummaries.removeValue(forKey: spot.id)
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

private struct SpotCardSummary {
    let spotID: String
    let activity: Activity
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

        spotID = app.selectedSpot.id
        activity = app.activity
        self.conditions = conditions
        self.decision = decision
        window = (app.currentSlot ?? app.upcomingSlot)?.window
        isActivityUnavailable = app.unavailableActivities.contains(app.activity)
    }

    init(
        spotID: String,
        activity: Activity,
        conditions: Conditions,
        decision: GoDecision,
        window: DateInterval?,
        isActivityUnavailable: Bool)
    {
        self.spotID = spotID
        self.activity = activity
        self.conditions = conditions
        self.decision = decision
        self.window = window
        self.isActivityUnavailable = isActivityUnavailable
    }

    static func load(
        spot: Spot,
        activity: Activity,
        provider: any ConditionsProviding,
        engine: DecisionEngine,
        now: Date) async -> SpotCardSummary?
    {
        do {
            let current = try await provider.conditions(for: spot, at: now)
            guard !Task.isCancelled else { return nil }
            let horizon = try await provider.forecast(
                for: spot,
                from: now,
                hours: ForecastStore.forecastHours)
            guard !Task.isCancelled else { return nil }
            let fullDecision = engine.decide(
                activity: activity,
                conditions: current,
                forecast: horizon)
            let slots = engine.windows(activity: activity, over: horizon)
            let activeWindow = slots.first { $0.window.contains(current.at) }?.window
                ?? slots.first { $0.window.start > current.at }?.window
            return SpotCardSummary(
                spotID: spot.id,
                activity: activity,
                conditions: current,
                decision: fullDecision,
                window: activeWindow,
                isActivityUnavailable: fullDecision.isDataUnavailable)
        } catch {
            return nil
        }
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
