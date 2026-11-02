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

    let store = ForecastStore()
    let engine = DecisionEngine()
    let provider: any ConditionsProviding
    private let selectionStorage: SpotSelectionStorage

    init(
        provider: any ConditionsProviding = AppModel.defaultProvider(),
        selectionStorage: SpotSelectionStorage = SpotSelectionStorage())
    {
        self.provider = provider
        self.selectionStorage = selectionStorage
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

    // MARK: - Data

    @MainActor
    func reload() async {
        // Clear the derived state before the await, so no surface can render the
        // previous spot's verdict or windows while the new data loads.
        decision = nil
        slots = []
        unavailableActivities = []
        overviews = []
        await store.load(spot: selectedSpot, provider: provider)
        refreshDecision()
    }

    @MainActor
    private func refreshDecision() {
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

        // M5: the widgets and the Live Activity read this snapshot. Written off
        // the main actor; a failure only means the widget keeps the previous
        // one, never a fabricated value.
        let snapshot = WidgetSnapshotBuilder.make(
            WidgetSnapshotBuilder.Input(
                conditions: conditions,
                overviews: overviews,
                activity: activity,
                decision: decision ?? engine.decide(activity: activity, conditions: conditions),
                timeZone: selectedSpot.timezone,
                isSampleData: usesSampleData))
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
        }

        // M5: the Live Activity reads that same snapshot, so the lock screen
        // and the widgets can never disagree on the verdict or the window.
        LiveActivityController.shared.sync(
            snapshot: snapshot,
            current: currentSlot,
            upcoming: upcomingSlot)
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
