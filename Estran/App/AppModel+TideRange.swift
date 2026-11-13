import EstranCore
import Foundation

/// The local tidal range (« marnage ») of the selected spot.
///
/// The national Brest coefficient stays computed, unvalidated and unshown
/// (`AGENTS.md` invariant 6). What the screens say instead is the day's
/// high-minus-low from the shipped model at the spot, with a category from the
/// terciles of that same model over its horizon.
extension AppModel {
    /// Computes the tidal-range terciles for `spot` off the main actor, once.
    ///
    /// A year of extrema is too slow for a view body, and the line must never
    /// make the first scroll hitch: the task runs at `.utility`, stores the
    /// result, and the observation triggers the redraw. Until then the views
    /// simply draw no marnage line.
    @MainActor
    func warmTideRangeBaseline(for spot: Spot) {
        guard tideRangeThresholds[spot.id] == nil,
              !tideRangeWarmups.contains(spot.id)
        else {
            return
        }
        tideRangeWarmups.insert(spot.id)
        let date = store.conditions?.at ?? Date()
        let spotID = spot.id
        Task { @MainActor [weak self] in
            // Only the pure computation leaves the main actor: `AppModel` itself
            // never crosses an isolation boundary.
            let thresholds = await Task.detached(priority: .utility) {
                TideRangeBaselineStore.thresholds(for: spot, at: date)
            }.value
            guard let self else { return }
            tideRangeWarmups.remove(spotID)
            if let thresholds {
                tideRangeThresholds[spotID] = thresholds
            }
        }
    }

    /// « Marnage 3,8 m · grande marée » for `conditions`, or `nil` while the
    /// baseline is being computed or when the model cannot give the day's range.
    func tideRangeLine(for conditions: Conditions) -> String? {
        guard let thresholds = tideRangeThresholds[conditions.spot.id] else {
            return nil
        }
        return TideRangeBaselineStore.line(
            for: conditions.tide,
            spot: conditions.spot,
            at: conditions.at,
            thresholds: thresholds)
    }
}
