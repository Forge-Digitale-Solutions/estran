import EstranCore
import Foundation

extension AppModel {
    /// Dominant blocker when the selected activity has no window in the next
    /// 48 h, so the UI can say *why* there is none instead of a bare
    /// « Aucun créneau ».
    var emptyWindowBlocker: ActivityBlocker? {
        guard slots.isEmpty else { return nil }
        return engine.dominantBlocker(activity: activity, over: store.forecast)
    }

    /// The cautions the « Créneaux » card shows, or `nil` when it shows no
    /// window.
    ///
    /// A caution shown next to a window describes **that window**, never the
    /// current instant (`W-NIGHTFIX`): a card that says « Pas de créneau d'ici
    /// 48 h » carries no caution at all, and a 16:00–19:00 window crossing
    /// sunset carries the night caution even when the app is opened at noon.
    /// The rain reminder reads the forecast sample closest to the window's
    /// start, so it describes the window's weather and not today's.
    var windowCaution: String? {
        guard let slot = currentSlot ?? upcomingSlot else { return nil }
        let sample = store.forecast.min {
            abs($0.at.timeIntervalSince(slot.window.start))
                < abs($1.at.timeIntervalSince(slot.window.start))
        }
        return ActivityCaution.windowCaution(
            activity: activity,
            window: slot.window,
            spot: selectedSpot,
            weather: sample?.weather)
    }
}
