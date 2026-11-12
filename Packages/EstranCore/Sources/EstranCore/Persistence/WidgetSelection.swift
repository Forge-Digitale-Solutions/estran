import Foundation

/// Resolves a widget's configured selection (« Automatique » or a specific
/// value) into the concrete spot and activity its timeline renders.
///
/// This is pure and shared, so the app and the widget cannot disagree on what
/// « Automatique » means: it follows the spot/activity selected in the app.
public enum WidgetSelection {
    /// The concrete spot a configured identifier refers to.
    ///
    /// `configuredID == nil` means « Automatique »: follow the app's selected
    /// spot (`selectedID`). An unknown identifier also falls back to the
    /// selected spot rather than silently jumping to the default spot.
    public static func spot(configuredID: String?, selectedID: String?) -> Spot {
        if let configuredID, let spot = SpotCatalog.spot(id: configuredID) {
            return spot
        }
        return SpotCatalog.spot(id: selectedID)
    }

    /// The concrete activity a configured value refers to, or the app's
    /// selected activity when `configured` is `nil`.
    public static func activity(
        configured: Activity?,
        snapshot: WidgetSnapshot?) -> Activity
    {
        if let configured {
            return configured
        }
        if let snapshot {
            return snapshot.activity
        }
        return .shoreFishing
    }

    /// The activities offered at `spot`, in the app's fixed order. Used by the
    /// widget's activity options provider, so « Automatique » always leads and
    /// surf never appears at a spot that does not offer it (Eyrac).
    public static func offeredActivities(at spot: Spot) -> [Activity] {
        spot.offeredActivities
    }
}
