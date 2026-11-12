import EstranCore
import Foundation
import WidgetKit

/// W-WIDGETCONF — the app writes one snapshot per spot, so a widget configured
/// to either spot has data without the app ever being open on it.
extension AppModel {
    /// Every offered activity's answer for the given conditions and forecast.
    /// Shared by the selected spot (`overviews`) and the other spot's background
    /// snapshot, so the two can never disagree on wording.
    static func overviews(
        for conditions: Conditions,
        forecast: [Conditions],
        engine: DecisionEngine) -> [ActivityOverview]
    {
        conditions.spot.offeredActivities.map { candidate in
            let decision = engine.decide(
                activity: candidate, conditions: conditions, forecast: forecast)
            let slots = engine.windows(activity: candidate, over: forecast)
            return ActivityOverview(
                activity: candidate,
                decision: decision,
                current: slots.first { $0.window.contains(conditions.at) },
                upcoming: slots.first { $0.window.start > conditions.at })
        }
    }

    /// M5: the widgets and the Live Activity read this snapshot. Written off the
    /// main actor; a failure only means the widget keeps the previous one, never
    /// a fabricated value.
    @MainActor
    func publishSnapshot(for conditions: Conditions) {
        let snapshot = WidgetSnapshotBuilder.make(
            WidgetSnapshotBuilder.Input(
                conditions: conditions,
                overviews: overviews,
                activity: activity,
                decision: decision,
                timeZone: selectedSpot.timezone,
                isSampleData: usesSampleData))
        // The notification scheduler reads the same snapshot and the same
        // windows, off the main actor: a refused or failed notification never
        // delays a refresh.
        let windows = slots
        let otherSpot = SpotCatalog.v1.first { $0.id != selectedSpot.id }
        let otherActivity = activity
        let conditionsProvider = provider
        let isSampleData = usesSampleData

        Task.detached(priority: .utility) {
            // The selected spot is written immediately; the other spot is
            // refreshed in the same task, so a widget configured to it stays
            // current without the app ever being open on it.
            Self.writeSnapshots(merging: [snapshot])
            WidgetCenter.shared.reloadAllTimelines()

            await LocalNotificationScheduler.shared.reschedule(
                for: snapshot, windows: windows, now: Date())

            if let otherSpot {
                await Self.refreshOtherSpotSnapshot(
                    spot: otherSpot,
                    activity: otherActivity,
                    provider: conditionsProvider,
                    isSampleData: isSampleData)
            }
        }

        // The Live Activity reads that same snapshot, so the lock screen and the
        // widgets can never disagree on the verdict or the window.
        LiveActivityController.shared.sync(
            snapshot: snapshot,
            current: currentSlot,
            upcoming: upcomingSlot)
    }

    /// Merges snapshots into the shared per-spot collection, keeping whatever
    /// the previous write already held for the other spots.
    static func writeSnapshots(merging snapshots: [WidgetSnapshot]) {
        var bySpot = WidgetSnapshot.loadCollection() ?? [:]
        for snapshot in snapshots {
            bySpot[snapshot.spotID] = snapshot
        }
        do {
            try WidgetSnapshot.saveCollection(Array(bySpot.values))
        } catch {
            // No App Group container: the widgets keep their previous snapshots
            // rather than showing a value we could not persist.
        }
    }

    /// Loads another spot's conditions and writes its snapshot, so a widget
    /// configured to that spot has data without the app ever opening it.
    ///
    /// No network here on the extension side: this runs in the app, which is
    /// the only process allowed to fetch. A failed fetch leaves the previous
    /// snapshot for that spot; it never fabricates a value.
    static func refreshOtherSpotSnapshot(
        spot: Spot,
        activity: Activity,
        provider: any ConditionsProviding,
        isSampleData: Bool) async
    {
        do {
            let now = Date()
            let conditions = try await provider.conditions(for: spot, at: now)
            let forecast = try await provider.forecast(
                for: spot, from: now, hours: ForecastStore.forecastHours)
            let engine = DecisionEngine()
            let overviews = overviews(for: conditions, forecast: forecast, engine: engine)
            let decision = engine.decide(
                activity: activity, conditions: conditions, forecast: forecast)
            let snapshot = WidgetSnapshotBuilder.make(
                WidgetSnapshotBuilder.Input(
                    conditions: conditions,
                    overviews: overviews,
                    activity: activity,
                    decision: decision,
                    timeZone: spot.timezone,
                    isSampleData: isSampleData))
            writeSnapshots(merging: [snapshot])
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // The other spot keeps its previous snapshot.
        }
    }
}
