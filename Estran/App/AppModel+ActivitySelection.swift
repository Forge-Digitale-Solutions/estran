import EstranCore

/// W-PERSIST — the chosen activity survives a relaunch, next to the spot.
///
/// The value used to reset to `.shoreFishing` on every launch while the spot
/// survived, so the app reopened on someone else's activity. It now lives in
/// the App Group (`ActivitySelectionStorage`) and is restored in `AppModel.init`,
/// before the first decision.
///
/// `select(activity:)` stays in `AppModel.swift` because it also refreshes the
/// decision; the write half of the selection lives here, so the widget deep
/// link and the picker share one persistence path.
@MainActor
extension AppModel {
    /// Applies a new activity **without** recomputing.
    ///
    /// `openWidget` needs the activity in place *before* the spot reload, so the
    /// decision is computed once against the freshly loaded conditions. Every
    /// other caller goes through `select(activity:)`, which refreshes after.
    ///
    /// An unchanged activity is not written: tapping the selected chip, or a
    /// widget carrying the current one, never invents a stored choice.
    func remember(activity newActivity: Activity) {
        guard newActivity != activity else { return }
        activity = newActivity
        activityStorage.save(newActivity)
    }
}
