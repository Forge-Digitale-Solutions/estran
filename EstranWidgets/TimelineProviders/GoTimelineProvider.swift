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

        let spot = SpotCatalog.spot(id: snapshot.spotID) ?? SpotCatalog.defaultSpot

        // Swimming is a risk level, never a verdict (invariant 1): the answer is
        // the level the app computed, in the same word the small widget shows.
        // `.unknown` is the fallback only when no advisory travelled with the
        // snapshot — never a made-up « low ». A not-offered activity (surf inside
        // the Bassin) is its own neutral state, never a `Non` and never missing
        // data.
        let answer: String
        let detail: String
        if snapshot.isNotOffered {
            answer = ActivityOffer.notOfferedTitle(activity: snapshot.activity, spot: spot)
            detail = ActivityOffer.notOfferedDetail(activity: snapshot.activity)
                ?? snapshot.answer
        } else if snapshot.activity == .swimming {
            answer = snapshot.swimmingAdvisory?.level.shortTitle
                ?? SwimmingRiskLevel.unknown.shortTitle
            detail = snapshot.answer
        } else if snapshot.isUnavailable {
            answer = "Données indisponibles"
            detail = snapshot.answer
        } else {
            answer = snapshot.isGo ? "Oui" : "Non"
            detail = snapshot.answer
        }

        return GoEntry(
            date: snapshot.updatedAt,
            title: snapshot.spotName,
            answer: answer,
            detail: detail,
            isSwimming: snapshot.activity == .swimming,
            swimmingAdvisory: snapshot.swimmingAdvisory,
            isGo: snapshot.isGo,
            isUnavailable: snapshot.isUnavailable,
            isNotOffered: snapshot.isNotOffered,
            lines: snapshot.lines,
            metrics: snapshot.metrics,
            isSampleData: snapshot.isSampleData,
            // The selected activity is carried explicitly: inferring it from
            // `lines` guessed another activity whenever two answers matched.
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
