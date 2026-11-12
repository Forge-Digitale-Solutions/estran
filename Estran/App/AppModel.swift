import EstranCore
import Foundation
import Observation
import WidgetKit

/// Loads one spot's conditions and forecast, and exposes them to every screen.
///
/// This is the **shared store** required by the M3 checklist: Home, the focus
/// map and (later) the spot detail all read the same values. The store owns no
/// decision logic — it holds data, `AppModel` asks the engine.
@Observable
final class ForecastStore {
    enum Phase: Equatable {
        case idle
        case loading
        case ready
        case unavailable(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var conditions: Conditions?
    private(set) var forecast: [Conditions] = []
    /// Monotonic token so a slow load for a previous spot cannot overwrite the
    /// newer selection when the user taps two chips quickly.
    private var generation = 0

    /// Number of hourly samples requested. 48 h covers "demain" without
    /// pretending to forecast a week of weather.
    static let forecastHours = 48

    @MainActor
    func load(spot: Spot, provider: any ConditionsProviding, now: Date = Date()) async {
        // Never keep the previous spot's values visible during a reload: the
        // title would name the new spot while the tide, wind and window still
        // describe the old one (early M3 review, point 2).
        generation += 1
        let token = generation
        phase = .loading
        conditions = nil
        forecast = []
        do {
            let current = try await provider.conditions(for: spot, at: now)
            guard token == generation else { return }
            let horizon = try await provider.forecast(
                for: spot, from: now, hours: Self.forecastHours)
            guard token == generation else { return }
            conditions = current
            forecast = horizon
            phase = .ready
        } catch let error as ConditionsProviderError {
            guard token == generation else { return }
            conditions = nil
            forecast = []
            phase = .unavailable(error.displayMessage)
        } catch {
            guard token == generation else { return }
            conditions = nil
            forecast = []
            phase = .unavailable("Les données sont indisponibles pour ce spot.")
        }
    }
}

/// Composition root: the single spot selection, the current activity, the
/// provider and the decision engine.
///
/// Exactly one spot is selected in the whole product (`DESIGN_REFERENCE.md`
/// §6.1). The selection is persisted in the App Group so the widget and Siri
/// read the same value.
@Observable
final class AppModel {
    private(set) var selectedTab: AppTab = .now
    private(set) var selectedSpot: Spot
    private(set) var activity: Activity = .shoreFishing
    private(set) var decision: GoDecision?
    private(set) var slots: [ActivitySlot] = []
    /// Every activity's answer for the selected spot, in `Activity.allCases`
    /// order. The spot detail and the activity picker read this, never their own
    /// engine call.
    private(set) var overviews: [ActivityOverview] = []
    /// Activities the current conditions cannot answer (missing national
    /// coefficient, missing sea temperature…). Rendered as a visible
    /// « Données indisponibles » state, never as a plain `Non`.
    private(set) var unavailableActivities: Set<Activity> = []
    /// The generated sentence for the current decision, `nil` until (or unless)
    /// the on-device model answers. The answer card keeps showing
    /// `decision.reason` while it is `nil`: no spinner, no placeholder.
    private(set) var refinedReason: String?

    let store = ForecastStore()
    let engine = DecisionEngine()
    let provider: any ConditionsProviding
    /// The sentence generator. A stored `let` so a test (or a preview) can
    /// inject `TemplateReasonProvider` and assert the display path without an
    /// eligible device.
    let reasonProvider: any ReasonTextProviding
    private let selectionStorage: SpotSelectionStorage
    /// The activity an `OpenIntent` asked for, one-shot: the intent runs inside
    /// this process, but a warm `AppModel` does not see the App Group write.
    private let intentSelection: IntentSelectionStorage
    /// The one generation in flight. Cancelled when the decision it describes
    /// is replaced, and never awaited, so a slow model cannot delay a refresh.
    @ObservationIgnored private var reasonTask: Task<Void, Never>?
    /// `true` once the on-device session was asked to load (M4 prewarm).
    @ObservationIgnored private var hasPrewarmedReasonSession = false

    init(
        provider: any ConditionsProviding = AppModel.defaultProvider(),
        selectionStorage: SpotSelectionStorage = SpotSelectionStorage(),
        intentSelection: IntentSelectionStorage = IntentSelectionStorage(),
        reasonProvider: any ReasonTextProviding = FoundationModelReasonProvider())
    {
        self.provider = provider
        self.selectionStorage = selectionStorage
        self.intentSelection = intentSelection
        self.reasonProvider = reasonProvider
        selectedSpot = SpotCatalog.spot(id: selectionStorage.load())
    }

    /// `true` while the app runs on the DEBUG demo provider.
    var usesSampleData: Bool {
        provider.isSampleData
    }

    /// The production provider is the live one; DEBUG builds use the demo
    /// provider so the UI can be built before M2, unless the app was launched
    /// with `-liveData` (simulator / device check of the real sources).
    static func defaultProvider() -> any ConditionsProviding {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-liveData") {
                return LiveConditionsProvider()
            }
            return DemoConditionsProvider()
        #else
            return LiveConditionsProvider()
        #endif
    }

    // MARK: - Navigation and selection

    @MainActor
    func select(tab: AppTab) {
        selectedTab = tab
    }

    @MainActor
    func select(spot: Spot) async {
        guard spot.id != selectedSpot.id else { return }
        selectedSpot = spot
        selectionStorage.save(spot.id)
        await reload()
    }

    @MainActor
    func select(activity: Activity) {
        guard activity != self.activity else { return }
        self.activity = activity
        refreshDecision()
    }

    /// Applies a spot (and, when it set one, an activity) chosen in Spotlight or
    /// an App Intent while the app was already running.
    ///
    /// `OpenSpotIntent` writes `SpotSelectionStorage`, `OpenActivityIntent`
    /// writes the one-shot activity key; a warm `AppModel` never re-reads either
    /// on its own, so the card kept describing the previous place. This is the
    /// only intent-specific code here: the work goes through `select(spot:)` and
    /// `select(activity:)`, so there is no second selection or decision path.
    /// Called on launch and every time the scene becomes active.
    @MainActor
    func applyIntentSelectionIfNeeded() async {
        // Read the activity before the spot reload: `select(activity:)` then
        // refreshes the decision against the freshly loaded conditions instead
        // of the previous spot's.
        let pendingActivity = intentSelection.consumeActivity()
        let storedSpot = SpotCatalog.spot(id: selectionStorage.load())
        if storedSpot.id != selectedSpot.id {
            await select(spot: storedSpot)
        }
        if let pendingActivity {
            select(activity: pendingActivity)
        }
    }

    // MARK: - Data

    @MainActor
    func reload() async {
        // M4: the on-device session is asked to load on the first activation,
        // off the critical path. It is a no-op when Apple Intelligence is
        // unavailable, and it never delays the refresh below.
        prewarmReasonSessionIfNeeded()
        // Clear the derived state before the await, so no surface can render the
        // previous spot's verdict or windows while the new data loads.
        decision = nil
        slots = []
        unavailableActivities = []
        overviews = []
        await store.load(spot: selectedSpot, provider: provider)
        refreshDecision()
    }

    /// Loads the on-device model session once, in the background, so the first
    /// generated sentence does not pay for it (`LanguageModelSession.prewarm`,
    /// iOS 26+). Called from the launch path; guarded so a spot change or a
    /// second activation never starts a second load. Nothing is shown, nothing
    /// is awaited, and the template sentence stays the floor.
    @MainActor
    func prewarmReasonSessionIfNeeded() {
        guard !hasPrewarmedReasonSession else { return }
        hasPrewarmedReasonSession = true
        prewarmReasonSession()
    }

    /// Re-warms the on-device session when the app comes back to the
    /// foreground: the system may have evicted it while backgrounded, and the
    /// first sentence after a return should not pay for the reload.
    ///
    /// A no-op when Apple Intelligence is unavailable
    /// (`FoundationModelReasonProvider.prewarm()` checks availability itself), when
    /// the build has no FoundationModels, and when a test or preview injected the
    /// template provider. Nothing is shown and nothing is awaited.
    @MainActor
    func prewarmReasonSession() {
        // A test or preview that injected the template provider has no model to
        // warm; `prewarm()` itself also checks availability.
        guard reasonProvider is FoundationModelReasonProvider else { return }
        Task.detached(priority: .utility) {
            FoundationModelReasonProvider.prewarm()
        }
    }

    @MainActor
    private func refreshDecision() {
        // The sentence describes one decision: drop it before anything else, so a
        // late answer for the previous spot or activity can never be rendered
        // under the new chip.
        reasonTask?.cancel()
        reasonTask = nil
        refinedReason = nil

        guard let conditions = store.conditions else {
            decision = nil
            slots = []
            unavailableActivities = []
            overviews = []
            // No data, no card: a running Live Activity would keep describing a
            // window the app can no longer compute (M5 review, finding 2).
            LiveActivityController.shared.endAll(reason: "conditions unavailable")
            return
        }

        decision = engine.decide(
            activity: activity, conditions: conditions, forecast: store.forecast)
        slots = engine.windows(activity: activity, over: store.forecast)
        recomputeOverviewAvailability(for: conditions)
        publishSnapshot(for: conditions)

        // M4: the generated sentence replaces the template line only once it
        // arrives. The snapshot above is written before this, so the widget
        // keeps the template reason by design.
        if let decision {
            refineReason(for: decision, conditions: conditions)
        }
    }

    /// Every activity's answer and unavailable flag for the current conditions,
    /// so the spot detail and the activity picker never call the engine.
    @MainActor
    private func recomputeOverviewAvailability(for conditions: Conditions) {
        var unavailable: Set<Activity> = []
        for candidate in Activity.allCases {
            let candidateDecision = engine.decide(activity: candidate, conditions: conditions)
            if candidateDecision.isDataUnavailable {
                unavailable.insert(candidate)
            }
        }
        unavailableActivities = unavailable

        overviews = Activity.allCases.map { candidate in
            let candidateDecision = engine.decide(
                activity: candidate, conditions: conditions, forecast: store.forecast)
            let candidateSlots = engine.windows(activity: candidate, over: store.forecast)
            return ActivityOverview(
                activity: candidate,
                decision: candidateDecision,
                current: candidateSlots.first { $0.window.contains(conditions.at) },
                upcoming: candidateSlots.first { $0.window.start > conditions.at })
        }
    }

    /// M5: the widgets and the Live Activity read this snapshot. Written off the
    /// main actor; a failure only means the widget keeps the previous one, never
    /// a fabricated value.
    @MainActor
    private func publishSnapshot(for conditions: Conditions) {
        let snapshot = WidgetSnapshotBuilder.make(
            WidgetSnapshotBuilder.Input(
                conditions: conditions,
                overviews: overviews,
                activity: activity,
                decision: decision ?? engine.decide(activity: activity, conditions: conditions),
                timeZone: selectedSpot.timezone,
                isSampleData: usesSampleData))
        // The notification scheduler reads the same snapshot and the same
        // windows, off the main actor: a refused or failed notification never
        // delays a refresh.
        let windows = slots
        Task.detached(priority: .utility) {
            do {
                try snapshot.save()
                // The widget reads the file; WidgetKit still needs a nudge to
                // rebuild its timeline from it.
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                // No App Group container: the widget keeps its previous
                // snapshot rather than showing a value we could not persist.
            }
            // M4: one notification per good window, rescheduled from scratch on
            // every refresh. The policy drops the ones already too close.
            await LocalNotificationScheduler.shared.reschedule(
                for: snapshot, windows: windows, now: Date())
        }

        // The Live Activity reads that same snapshot, so the lock screen and the
        // widgets can never disagree on the verdict or the window.
        LiveActivityController.shared.sync(
            snapshot: snapshot,
            current: currentSlot,
            upcoming: upcomingSlot)
    }

    /// Asks `reasonProvider` for one sentence, and keeps the answer only while
    /// the decision it was written for is still on screen.
    ///
    /// The instant and the activity are captured **before** the await and
    /// compared after it: a slow answer for a previous activity (or for a spot
    /// the user has just left) is dropped, never displayed. The closure holds
    /// `self` weakly and re-reads it only after the await, so a closed view
    /// releases the model and the store instead of being kept alive by a
    /// pending generation.
    @MainActor
    private func refineReason(for decision: GoDecision, conditions: Conditions) {
        let provider = reasonProvider
        let activity = decision.activity
        let computedAt = decision.computedAt
        reasonTask = Task { @MainActor [weak self] in
            let text = await provider.reason(for: decision, conditions: conditions)
            guard !Task.isCancelled, let self else { return }
            // Stale-answer guard: same activity, same decision instant.
            guard let current = self.decision,
                  current.activity == activity,
                  current.computedAt == computedAt
            else { return }
            let sentence = text.trimmingCharacters(in: .whitespacesAndNewlines)
            // An empty answer never blanks the card: the template stays.
            guard !sentence.isEmpty else { return }
            refinedReason = sentence
        }
    }

    // MARK: - Windows

    /// The good window that contains "now", when the verdict is `Oui`.
    var currentSlot: ActivitySlot? {
        guard let now = store.conditions?.at else { return nil }
        return slots.first { $0.window.contains(now) }
    }

    /// The first good window that starts after "now".
    var upcomingSlot: ActivitySlot? {
        guard let now = store.conditions?.at else { return nil }
        return slots.first { $0.window.start > now }
    }
}
