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
}
