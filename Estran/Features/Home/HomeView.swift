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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Shared by the chips' droplet and the answer card, so the two morphs
    /// belong to the same glass rendering pass.
    @Namespace private var glassNamespace

    /// One identity for the answer area in both of its shapes: switching to or
    /// from Baignade changes what the card says, not which glass is on screen,
    /// so the surface materialises instead of popping.
    private static let answerGlassID = "answer-card"

    private func usesTwoColumns(width: CGFloat) -> Bool {
        OceanLayout.usesTwoColumns(
            width: width,
            sizeClass: horizontalSizeClass,
            dynamicTypeSize: dynamicTypeSize)
    }

    var body: some View {
        NavigationStack {
            // The reader supplies the window width to the layout; the scroll
            // view inside it keeps its own scrolling. A width read with
            // `onGeometryChange` would update state during layout, which
            // `ImageRenderer` cannot do (the render tests crash without this).
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: OceanSpacing.lg) {
                        headerRow
                        titleBlock
                        if usesTwoColumns(width: proxy.size.width) {
                            wideBody
                        } else {
                            phoneBody
                        }
                        attribution
                    }
                    .padding(.horizontal, OceanSpacing.md)
                    .padding(.top, OceanSpacing.sm)
                    .padding(.bottom, OceanSpacing.xxl)
                    .oceanReadableWidth()
                }
                .background { OceanBackdrop() }
                // The bar is hidden, so cards pass under the status bar and
                // above the floating tab bar: the soft pocket keeps both edges
                // legible (`docs/design/ios27-opportunities.md`, item 6). The
                // system turns it into an opaque bar under Reduce Transparency
                // by itself.
                .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
                // A wide window is short: 402 pt in landscape, 669 pt on the
                // unfolded Duo. There the two-column page is taller than the
                // window and the floating tab bar sits over its last lines, so
                // the wide shape keeps an explicit bottom margin on top of the
                // system inset. The phone shape is unchanged.
                .contentMargins(
                    .bottom,
                    usesTwoColumns(width: proxy.size.width) ? OceanSpacing.xxl : 0,
                    for: .scrollContent)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
            }
        }
    }

    // MARK: - Shape

    /// Phone (and Duo folded): one column, the Figma order, unchanged.
    @ViewBuilder
    private var phoneBody: some View {
        answerColumn
        nextWindowSection
        conditionsSection(columns: nil)
    }

    /// Duo unfolded / width ≥ 700 pt: the answer keeps the leading column at a
    /// comfortable measure and the secondary cards use the space beside it,
    /// instead of being stretched across 951 pt or pushed below the fold.
    /// Reading order stays answer → next window → conditions, which is also the
    /// VoiceOver order (`HStack` children are read in order).
    private var wideBody: some View {
        HStack(alignment: .top, spacing: OceanLayout.columnSpacing) {
            answerColumn
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: OceanSpacing.lg) {
                nextWindowSection
                // Four tiles need ~400 pt; the 340 pt side column gets two per
                // row rather than four squeezed ones.
                conditionsSection(columns: 2)
            }
            .frame(
                minWidth: OceanLayout.sideColumnMinimumWidth,
                idealWidth: OceanLayout.sideColumnIdealWidth,
                maxWidth: OceanLayout.sideColumnMaximumWidth,
                alignment: .leading)
        }
    }

    // MARK: - Sections

    /// The segmented control and the answer card are adjacent glass shapes: the
    /// container lets them merge as the system does (`ARCHITECTURE_PLAN.md`
    /// §12.3).
    private var answerColumn: some View {
        GlassEffectContainer(spacing: OceanSpacing.sm) {
            VStack(alignment: .leading, spacing: OceanSpacing.sm) {
                ActivitySegmentedControl(
                    selection: app.activity,
                    unavailable: app.unavailableActivities,
                    supported: app.selectedSpot.supportedActivities,
                    onSelect: { app.select(activity: $0) })
                answerSection
                    .glassEffectID(Self.answerGlassID, in: glassNamespace)
                    .glassEffectTransition(answerTransition)
                    // The morph is a glass transition, so the selection itself
                    // has to be animated here: nothing upstream wraps the change
                    // in `withAnimation`. Reduce Motion passes `nil`.
                    .animation(
                        OceanGlass.animation(
                            .spring(response: 0.45, dampingFraction: 0.86),
                            reduceMotion: reduceMotion),
                        value: app.activity)
            }
        }
    }

    /// Swimming has no "good window": it is a risk level, not a verdict. A
    /// not-offered activity has none either: it is not a verdict.
    @ViewBuilder
    private var nextWindowSection: some View {
        if case .ready = app.store.phase, app.activity != .swimming,
           !app.isActivityNotOffered
        {
            NextWindowCard(
                current: app.currentSlot,
                upcoming: app.upcomingSlot,
                isUnavailable: app.unavailableActivities.contains(app.activity),
                noWindowReason: FrenchFormat.emptyWindowReason(app.emptyWindowBlocker),
                timeZone: app.selectedSpot.timezone,
                reference: referenceDate,
                caution: app.windowCaution)
        }
    }

    @ViewBuilder
    private func conditionsSection(columns: Int?) -> some View {
        if let conditions = app.store.conditions {
            ConditionsGrid(conditions: conditions, preferredColumns: columns)
            // The swimming advisory card already carries the full warning; a
            // second tip would duplicate it, and a not-offered activity has no
            // tip either.
            if app.activity != .swimming, !app.isActivityNotOffered {
                TipCard(activity: app.activity)
            }
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
            if app.isActivityNotOffered {
                NotOfferedCard(
                    activity: app.activity,
                    spot: app.selectedSpot,
                    onSwitchSpot: { app.select(tab: .spots) })
            } else if let decision = app.decision, let conditions = app.store.conditions {
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
        VStack(alignment: .leading, spacing: OceanSpacing.xs) {
            Text("Source : REFMAR / Shom — Licence Ouverte 2.0 — modèle local non officiel.")
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
            // The weather credit sits with the tide one: WeatherKit's mark (or
            // the Open-Meteo CC BY line) only when that source produced the
            // values above, never for sample data.
            WeatherAttributionFooter(spotID: app.selectedSpot.id)
        }
    }
}

#Preview {
    HomePreview()
}

// The unfolded Duo: 951 × 669 pt, regular width. The static preview is the
// only way to see the two-column shape on a Mac; the App Store PNGs are the
// render tests' job (`DuoLayoutRenderTests`).
#Preview("Duo déplié — 951 × 669 pt", traits: .fixedLayout(width: 951, height: 669)) {
    HomePreview()
        .environment(\.horizontalSizeClass, .regular)
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
