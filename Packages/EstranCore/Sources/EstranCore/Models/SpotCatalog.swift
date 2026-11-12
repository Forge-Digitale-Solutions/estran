import Foundation

/// The v1 spot catalog: **two gauged spots only** (D3 = Option A).
///
/// The catalog lives in `EstranCore`, not in the app, because the app, the
/// widgets, the Live Activity and the App Intents must all read the same two
/// spots and the same identifiers. Adding a third spot here without a dataset
/// entry is a contract violation, caught by `SpotCatalogTests`.
///
/// Coordinates are the architect's proposed WGS84 values from
/// `DESIGN_REFERENCE.md` §4.0. They still require an IGN/OSM check before the
/// first release; they are not treated as surveyed.
///
/// The envelopes duplicate the shipped dataset on purpose: the catalog is the
/// compile-time truth used before the dataset loads, and the test
/// `testCatalogEnvelopesMatchTheShippedDataset` fails if the two drift.
public enum SpotCatalog {
    /// Pointe de Grave / Le Verdon-sur-Mer, tide reference `PORT-BLOC` (15).
    public static let pointeDeGrave = Spot(
        id: "pointe-de-grave",
        name: "Pointe de Grave",
        region: .medoc,
        // The catalog coordinate is the PORT-BLOC tide station, on the Gironde
        // estuary shore. Surf, swell and sea temperature describe the ocean
        // (Atlantic) beach just west of the point, so they are sampled at
        // `marineCoordinate`, ~500 m offshore of that beach (open water).
        coordinate: Coordinate(latitude: 45.570, longitude: -1.062),
        marineCoordinate: Coordinate(latitude: 45.570, longitude: -1.083),
        tideStation: TideStationRef(id: "15", name: "PORT-BLOC"),
        supportedActivities: Set(Activity.allCases),
        timezone: TimeZone(identifier: "Europe/Paris") ?? .gmt,
        // Ocean beach just west of the point: OSM coastline way 4543169 runs
        // ~SW (bearing ≈ 235°) there, with the Atlantic to the north-west, so
        // the seaward normal is ≈ 325°. Verified 2026-11-12 with a live
        // Open-Meteo Marine request at (45.570, -1.083): returns waves
        // (H ≈ 0.84 m, 11 s, dir 267°, SST 14.8 °C) — the grid cell is water.
        coastOrientationDegrees: 325,
        minimumWaterHeight: nil,
        validation: .gauged,
        correctionStatus: .none,
        uncertainty: TideUncertainty(timeMinutes: 75, heightMeters: 0.60),
        swimmingRange: SwimmingRange(lowBelow: 4.03, strongAt: 4.63))

    /// Arcachon — Jetée Thiers / Eyrac, tide reference `ARCACHON_EYRAC` (190).
    public static let arcachonEyrac = Spot(
        id: "arcachon-eyrac",
        name: "Arcachon-Eyrac",
        region: .bassin,
        coordinate: Coordinate(latitude: 44.661, longitude: -1.169),
        tideStation: TideStationRef(id: "190", name: "ARCACHON_EYRAC"),
        // Surf is not offered here: the Eyrac jetty is inside the Bassin and
        // nobody surfs there (owner decision 2026-11-12). The four other
        // activities keep their rules.
        supportedActivities: Set(Activity.allCases).subtracting([.surfing]),
        timezone: TimeZone(identifier: "Europe/Paris") ?? .gmt,
        // The town shore faces north into the Bassin (OSM coastline way
        // 516130770, Jetée Thiers: shoreline runs ~E–W, water north, seaward
        // normal ≈ 2°). Checked 2026-11-12. The previous 250° was wrong.
        coastOrientationDegrees: 0,
        minimumWaterHeight: nil,
        validation: .gauged,
        correctionStatus: .none,
        uncertainty: TideUncertainty(timeMinutes: 70, heightMeters: 0.70),
        swimmingRange: SwimmingRange(lowBelow: 3.58, strongAt: 4.18))

    /// The two shipped spots, in display order (ocean first, then the Bassin).
    public static let v1: [Spot] = [pointeDeGrave, arcachonEyrac]

    /// Default selection when the user has never chosen a spot.
    public static var defaultSpot: Spot {
        pointeDeGrave
    }

    /// Looks a spot up by its stable identifier.
    public static func spot(id: String) -> Spot? {
        v1.first { $0.id == id }
    }

    /// Resolves a stored identifier, falling back to the default spot.
    ///
    /// A stale or unknown identifier never removes a spot from the UI: it falls
    /// back to the default and the stored value is overwritten on the next
    /// selection.
    public static func spot(id: String?) -> Spot {
        guard let id, let spot = spot(id: id) else { return defaultSpot }
        return spot
    }
}
