import EstranCore
import SwiftUI

/// 01 — Accueil. The definitive Home layout, wired to the shared store.
///
/// Everything lives in a `ScrollView`: at AX5 the answer card, the tiles and the
/// segmented control grow instead of clipping. There is no fixed text height and
/// no Dynamic Type clamp.
struct HomeView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Shared by the chips' droplet and the answer card, so the two morphs
    /// belong to the same glass rendering pass.
    @Namespace private var glassNamespace

    /// One identity for the answer area in both of its shapes: switching to or
    /// from Baignade changes what the card says, not which glass is on screen,
    /// so the surface materialises instead of popping.
    private static let answerGlassID = "answer-card"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: OceanSpacing.lg) {
                    headerRow
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
                                .glassEffectID(Self.answerGlassID, in: glassNamespace)
                                .glassEffectTransition(answerTransition)
                                // The morph is a glass transition, so the
                                // selection itself has to be animated here:
                                // nothing upstream wraps the change in
                                // `withAnimation`. Reduce Motion passes `nil`.
                                .animation(
                                    OceanGlass.animation(
                                        .spring(response: 0.45, dampingFraction: 0.86),
                                        reduceMotion: reduceMotion),
                                    value: app.activity)
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
            .background { OceanBackdrop() }
            // The bar is hidden, so cards pass under the status bar and above
            // the floating tab bar: the soft pocket keeps both edges legible
            // (`docs/design/ios27-opportunities.md`, item 6). The system turns
            // it into an opaque bar under Reduce Transparency by itself.
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    /// `.identity` under Reduce Motion: the card still changes, the glass does
    /// not travel or dissolve.
    private var answerTransition: GlassEffectTransition {
        reduceMotion ? .identity : .materialize
    }

    /// Spot pill and the prototype badge, inside the scroll content.
    ///
    /// They used to live in the navigation toolbar, where the glass button style
    /// collapsed the pill to its icon and clipped the spot name. `DESIGN_REFERENCE.md`
    /// §3.1 puts this row above the large title, which is also where it reads
    /// best at AX sizes.
    ///
    /// At accessibility sizes the two controls cannot share a line: the spot
    /// name alone is wider than the screen, so the row stacks. Nothing is
    /// clamped and nothing is truncated.
    @ViewBuilder
    private var headerRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: OceanSpacing.xs) {
                spotButton
                sampleBadge
            }
        } else {
            HStack(spacing: OceanSpacing.sm) {
                spotButton
                Spacer(minLength: OceanSpacing.xs)
                sampleBadge
            }
        }
    }

    private var spotButton: some View {
        SpotButton(name: app.selectedSpot.name) {
            app.select(tab: .spots)
        }
    }

    @ViewBuilder
    private var sampleBadge: some View {
        if app.usesSampleData {
            SampleDataBadge()
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
                .accessibilityIdentifier("app.title")
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
                        conditions: conditions,
                        refinedReason: app.refinedReason)
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
