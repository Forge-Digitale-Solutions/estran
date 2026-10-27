import EstranCore
import SwiftUI

/// 01 — Accueil. The definitive Home layout, wired to the shared store.
///
/// Everything lives in a `ScrollView`: at AX5 the answer card, the tiles and the
/// segmented control grow instead of clipping. There is no fixed text height and
/// no Dynamic Type clamp.
struct HomeView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: OceanSpacing.lg) {
                    titleBlock
                    // The segmented control and the answer card are adjacent
                    // glass shapes: the container lets them merge as the system
                    // does (`ARCHITECTURE_PLAN.md` §12.3).
                    GlassEffectContainer(spacing: OceanSpacing.sm) {
                        VStack(alignment: .leading, spacing: OceanSpacing.sm) {
                            ActivitySegmentedControl(
                                selection: app.activity,
                                unavailable: app.unavailableActivities,
                                onSelect: { app.select(activity: $0) })
                            answerSection
                        }
                    }
                    // Swimming has no "good window": it is a risk level, not a verdict.
                    if case .ready = app.store.phase, app.activity != .swimming {
                        NextWindowCard(
                            current: app.currentSlot,
                            upcoming: app.upcomingSlot,
                            isUnavailable: app.unavailableActivities.contains(app.activity),
                            timeZone: app.selectedSpot.timezone,
                            reference: referenceDate)
                    }
                    if let conditions = app.store.conditions {
                        ConditionsGrid(conditions: conditions)
                        // The swimming advisory card already carries the full
                        // warning; a second tip would duplicate it.
                        if app.activity != .swimming {
                            TipCard(activity: app.activity)
                        }
                    }
                    attribution
                }
                .padding(.horizontal, OceanSpacing.md)
                .padding(.top, OceanSpacing.sm)
                .padding(.bottom, OceanSpacing.xxl)
            }
            .background(OceanPalette.backgroundGradient.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
    }

    private var referenceDate: Date {
        app.store.conditions?.at ?? Date()
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
            Text("Maintenant")
                .font(OceanTypography.largeTitle)
                .foregroundStyle(OceanPalette.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(
                "\(app.selectedSpot.name) · "
                    + FrenchFormat.time(referenceDate, in: app.selectedSpot.timezone))
                .font(OceanTypography.subtitle)
                .foregroundStyle(OceanPalette.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var answerSection: some View {
        switch app.store.phase {
        case .idle, .loading:
            LoadingCard()
        case .ready:
            if let decision = app.decision, let conditions = app.store.conditions {
                if app.activity == .swimming {
                    SwimmingAdvisoryCard(
                        advisory: SwimmingAdvisory(
                            decision: decision,
                            conditions: conditions))
                } else {
                    AnswerCard(
                        decision: decision,
                        activity: app.activity,
                        conditions: conditions)
                }
            } else if app.activity == .swimming {
                SwimmingAdvisoryCard(
                    advisory: SwimmingAdvisory(
                        level: .unknown,
                        region: app.selectedSpot.region))
            } else {
                UnavailableCard(message: "Les données sont indisponibles pour ce spot.")
            }
        case let .unavailable(message):
            if app.activity == .swimming {
                SwimmingAdvisoryCard(
                    advisory: SwimmingAdvisory(
                        level: .unknown,
                        region: app.selectedSpot.region))
            } else {
                UnavailableCard(message: message)
            }
        }
    }

    private var attribution: some View {
        Text("Source : REFMAR / Shom — Licence Ouverte 2.0 — modèle local non officiel.")
            .font(OceanTypography.smallLabel)
            .foregroundStyle(OceanPalette.white.opacity(0.6))
            .fixedSize(horizontal: false, vertical: true)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            SpotButton(name: app.selectedSpot.name) {
                app.select(tab: .spots)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if app.usesSampleData {
                SampleDataBadge()
            }
        }
    }
}

private struct LoadingCard: View {
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
        .oceanGlassCard(cornerRadius: OceanGlass.answerCornerRadius)
        .accessibilityElement(children: .combine)
    }
}

/// Visible unavailable state. It is not an error to hide: the card explains why
/// the data cannot answer, and the rest of the screen keeps working.
private struct UnavailableCard: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.sm) {
            Text("BON MOMENT POUR SORTIR ?")
                .font(OceanTypography.smallLabel)
                .tracking(1.2)
                .foregroundStyle(OceanPalette.white.opacity(0.7))

            HStack(alignment: .center, spacing: OceanSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(OceanTypography.metricValue)
                    .foregroundStyle(OceanPalette.unavailable)
                    .accessibilityHidden(true)
                Text("Données indisponibles")
                    .font(OceanTypography.metricValue)
                    .foregroundStyle(OceanPalette.unavailable)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(message)
                .font(OceanTypography.subtitle)
                .foregroundStyle(OceanPalette.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(OceanSpacing.lg)
        .oceanGlassCard(cornerRadius: OceanGlass.answerCornerRadius)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HomePreview()
}

/// Previews load the demo forecast: without a Mac, the preview is the only way
/// to see the screen, so it must not sit on « Chargement » forever.
private struct HomePreview: View {
    @State private var app = AppModel()

    var body: some View {
        HomeView()
            .environment(app)
            .task { await app.reload() }
    }
}
