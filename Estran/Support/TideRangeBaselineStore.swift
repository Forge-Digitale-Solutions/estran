import EstranCore
import Foundation

/// Computes the local marnage baseline for one spot.
///
/// The shipped model's horizon is fixed, so the terciles are computed **once per
/// spot** and memoised by `AppModel` — the Home line and the spot-detail card
/// then read the same value, and opening a card never replays a year of
/// harmonics. Everything here is pure and `nonisolated`: `AppModel` runs it off
/// the main actor, because a year of extrema costs more than one frame.
///
/// A missing model, station or day returns `nil`: the line is then not drawn at
/// all, never guessed (invariant 3).
enum TideRangeBaselineStore {
    static func thresholds(for spot: Spot, at date: Date) -> TideRangeThresholds? {
        guard let model = try? ShippedTideModel.load(),
              let station = model.stations
                  .first(where: { $0.id == spot.tideStation.id })?
                  .tidalStation
        else {
            return nil
        }
        return TideRangeBaseline.thresholds(station: station, from: date)
    }

    /// « Marnage 3,8 m · grande marée », or `nil` when the model cannot give the
    /// day's range.
    static func line(
        for tide: TideState,
        spot: Spot,
        at date: Date,
        thresholds: TideRangeThresholds) -> String?
    {
        guard let day = TideRangeBaseline.day(
            of: tide,
            in: spot.timezone,
            at: date,
            thresholds: thresholds)
        else {
            return nil
        }
        return FrenchFormat.tideRangeLine(day)
    }
}
