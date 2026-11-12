import EstranCore
import Foundation
import WidgetKit

/// Reads the per-spot snapshot the app wrote in the App Group, then renders the
/// spot and activity the user configured.
///
/// The widget extension has no network, no store and no engine: it renders what
/// the app computed. « Automatique » follows the app's selection; a specific
/// spot or activity reads that spot's snapshot and that activity's line.
struct GoTimelineProvider: AppIntentTimelineProvider {
    typealias Intent = ConfigureGoWidgetIntent

    func placeholder(in _: Context) -> GoEntry {
        .placeholder
    }

    func snapshot(for configuration: Intent, in _: Context) async -> GoEntry {
        Self.entry(for: configuration)
    }

    func timeline(for configuration: Intent, in _: Context) async -> Timeline<GoEntry> {
        let entry = Self.entry(for: configuration)
        // Fresh data: reload in 30 min (the app refreshes every hour anyway).
        // Stale or missing: ask again sooner; the app writes a new snapshot on
        // its next refresh and calls `WidgetCenter.reloadAllTimelines()`.
        let stale = entry.isEmpty || entry.isStale
        let delay: TimeInterval = stale ? 15 * 60 : 30 * 60
        return Timeline(
            entries: [entry],
            policy: .after(Date().addingTimeInterval(delay)))
    }

    /// Resolves the configured spot and activity, then builds the entry from the
    /// matching snapshot. Pure so it can be shared with the Conditions provider
    /// and unit-tested through `GoEntry.make`.
    static func entry(for configuration: Intent) -> GoEntry {
        let selectedID = SpotSelectionStorage().load()
        let spot = configuration.spot.resolvedSpot(selectedID: selectedID)
        let snapshot = WidgetSnapshot.load(forSpotID: spot.id)
        let activity = WidgetSelection.activity(
            configured: configuration.activity.activity,
            snapshot: snapshot)
        return GoEntry.make(snapshot: snapshot, spot: spot, activity: activity)
    }
}

extension GoEntry {
    /// Builds an entry for one concrete spot + activity from the shared snapshot.
    ///
    /// A missing or stale snapshot becomes the honest placeholder (the view adds
    /// « Ouvre l'app… »). A not-offered activity (surf at Eyrac) is the
    /// not-offered sentence, never `Oui`/`Non`. Swimming is a level, never a
    /// verdict (Invariant 1).
    static func make(
        snapshot: WidgetSnapshot?,
        spot: Spot,
        activity: Activity) -> GoEntry
    {
        guard let snapshot else {
            return missingEntry(spot: spot, activity: activity)
        }
        guard spot.supports(activity) else {
            return notOfferedEntry(snapshot: snapshot, spot: spot, activity: activity)
        }
        if activity == .swimming {
            return swimmingEntry(snapshot: snapshot, spot: spot)
        }
        if let line = snapshot.lines.first(where: { $0.activity == activity }) {
            return lineEntry(snapshot: snapshot, spot: spot, activity: activity, line: line)
        }
        // No line for an offered activity cannot happen in a well-formed
        // snapshot; report it as unavailable rather than inventing a verdict.
        return unavailableEntry(snapshot: snapshot, spot: spot, activity: activity)
    }

    // MARK: - Entry builders

    private static func missingEntry(spot: Spot, activity: Activity) -> GoEntry {
        GoEntry(
            date: Date(),
            title: spot.name,
            answer: "—",
            detail: "Ouvre l'app pour charger les conditions",
            isGo: false,
            spotID: spot.id,
            selectedActivity: activity)
    }

    private static func notOfferedEntry(
        snapshot: WidgetSnapshot, spot: Spot, activity: Activity) -> GoEntry
    {
        GoEntry(
            date: snapshot.updatedAt,
            title: spot.name,
            answer: ActivityOffer.notOfferedTitle(activity: activity, spot: spot),
            detail: ActivityOffer.notOfferedDetail(activity: activity) ?? snapshot.answer,
            isGo: false,
            isNotOffered: true,
            lines: snapshot.lines,
            metrics: snapshot.metrics,
            isSampleData: snapshot.isSampleData,
            spotID: spot.id,
            selectedActivity: activity)
    }

    private static func swimmingEntry(snapshot: WidgetSnapshot, spot: Spot) -> GoEntry {
        let line = snapshot.lines.first { $0.activity == .swimming }
        let level = line?.swimmingLevel
            ?? snapshot.swimmingAdvisory?.level
            ?? .unknown
        let advisory = snapshot.swimmingAdvisory
            ?? SwimmingAdvisory(level: level, region: spot.region)
        return GoEntry(
            date: snapshot.updatedAt,
            title: spot.name,
            answer: level.shortTitle,
            detail: line?.answer ?? snapshot.answer,
            isSwimming: true,
            swimmingAdvisory: advisory,
            isGo: false,
            isUnavailable: line?.isUnavailable ?? snapshot.isUnavailable,
            lines: snapshot.lines,
            metrics: snapshot.metrics,
            isSampleData: snapshot.isSampleData,
            spotID: spot.id,
            selectedActivity: .swimming)
    }

    private static func lineEntry(
        snapshot: WidgetSnapshot, spot: Spot, activity: Activity,
        line: WidgetSnapshot.ActivityLine) -> GoEntry
    {
        GoEntry(
            date: snapshot.updatedAt,
            title: spot.name,
            answer: line.isUnavailable
                ? "Données indisponibles"
                : (line.isGo ? "Oui" : "Non"),
            detail: line.answer,
            isGo: line.isGo,
            isUnavailable: line.isUnavailable,
            lines: snapshot.lines,
            metrics: snapshot.metrics,
            isSampleData: snapshot.isSampleData,
            spotID: spot.id,
            selectedActivity: activity)
    }

    private static func unavailableEntry(
        snapshot: WidgetSnapshot, spot: Spot, activity: Activity) -> GoEntry
    {
        GoEntry(
            date: snapshot.updatedAt,
            title: spot.name,
            answer: "Données indisponibles",
            detail: snapshot.answer,
            isGo: false,
            isUnavailable: true,
            lines: snapshot.lines,
            metrics: snapshot.metrics,
            isSampleData: snapshot.isSampleData,
            spotID: spot.id,
            selectedActivity: activity)
    }

    /// Builds the Conditions entry: the four metrics for one concrete spot.
    static func conditions(snapshot: WidgetSnapshot?, spot: Spot) -> GoEntry {
        guard let snapshot else {
            return GoEntry(
                date: Date(),
                title: spot.name,
                answer: "—",
                detail: "Ouvre l'app pour charger les conditions",
                isGo: false,
                spotID: spot.id,
                selectedActivity: .shoreFishing)
        }
        return GoEntry(
            date: snapshot.updatedAt,
            title: spot.name,
            answer: snapshot.answer,
            detail: snapshot.answer,
            isGo: snapshot.isGo,
            isUnavailable: snapshot.isUnavailable,
            isNotOffered: snapshot.isNotOffered,
            lines: snapshot.lines,
            metrics: snapshot.metrics,
            isSampleData: snapshot.isSampleData,
            spotID: spot.id,
            selectedActivity: snapshot.activity)
    }
}

extension GoEntry {
    static let placeholder = GoEntry(
        date: Date(),
        title: "Estran",
        answer: "—",
        detail: "Ouvre l'app pour charger les conditions")
}
