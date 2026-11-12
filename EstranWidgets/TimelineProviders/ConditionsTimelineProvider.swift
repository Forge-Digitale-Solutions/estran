import EstranCore
import Foundation
import WidgetKit

/// The Conditions widget's timeline: reads the configured spot's snapshot and
/// renders its four metrics. No network, no engine — same data path as Go.
struct ConditionsTimelineProvider: AppIntentTimelineProvider {
    typealias Intent = ConfigureConditionsWidgetIntent

    func placeholder(in _: Context) -> GoEntry {
        .placeholder
    }

    func snapshot(for configuration: Intent, in _: Context) async -> GoEntry {
        Self.entry(for: configuration)
    }

    func timeline(for configuration: Intent, in _: Context) async -> Timeline<GoEntry> {
        let entry = Self.entry(for: configuration)
        let delay: TimeInterval = entry.isEmpty || entry.isStale ? 15 * 60 : 30 * 60
        return Timeline(
            entries: [entry],
            policy: .after(Date().addingTimeInterval(delay)))
    }

    static func entry(for configuration: Intent) -> GoEntry {
        let selectedID = SpotSelectionStorage().load()
        let spot = configuration.spot.resolvedSpot(selectedID: selectedID)
        let snapshot = WidgetSnapshot.load(forSpotID: spot.id)
        return GoEntry.conditions(snapshot: snapshot, spot: spot)
    }
}
