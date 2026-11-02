import EstranCore
import Foundation
import WidgetKit

/// Reads the snapshot the app wrote in the App Group.
///
/// The widget extension has no network, no store and no engine: it renders what
/// the app computed. Without a snapshot it shows a neutral placeholder (« — »),
/// never a made-up verdict. A stale snapshot is still shown but the timeline asks
/// to be reloaded soon.
struct GoTimelineProvider: TimelineProvider {
    func placeholder(in _: Context) -> GoEntry {
        .placeholder
    }

    func getSnapshot(in _: Context, completion: @escaping (GoEntry) -> Void) {
        completion(Self.entry(from: WidgetSnapshot.load()))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<GoEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        let entry = Self.entry(from: snapshot)
        // Fresh data: reload in 30 min (the app refreshes every hour anyway).
        // Stale or missing: ask again sooner; the app writes a new snapshot on
        // its next refresh and calls `WidgetCenter.reloadAllTimelines()`.
        let delay: TimeInterval = snapshot == nil || snapshot?.isStale == true
            ? 15 * 60
            : 30 * 60
        completion(
            Timeline(
                entries: [entry],
                policy: .after(Date().addingTimeInterval(delay))))
    }

    static func entry(from snapshot: WidgetSnapshot?) -> GoEntry {
        guard let snapshot else { return .placeholder }

        let answer: String = if snapshot.activity == .swimming {
            SwimmingRiskLevel.unknown.shortTitle
        } else if snapshot.isUnavailable {
            "Données indisponibles"
        } else {
            snapshot.isGo ? "Oui" : "Non"
        }

        return GoEntry(
            date: snapshot.updatedAt,
            title: snapshot.spotName,
            answer: answer,
            detail: snapshot.answer,
            isSwimming: snapshot.activity == .swimming,
            swimmingAdvisory: snapshot.swimmingAdvisory,
            isGo: snapshot.isGo,
            isUnavailable: snapshot.isUnavailable,
            lines: snapshot.lines,
            metrics: snapshot.metrics,
            isSampleData: snapshot.isSampleData)
    }
}

extension GoEntry {
    static let placeholder = GoEntry(
        date: Date(),
        title: "Estran",
        answer: "—",
        detail: "Ouvre l'app pour charger les conditions")
}
