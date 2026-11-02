import EstranCore
import Foundation

/// Wind-sea estimate for a spot the wave model does not resolve.
///
/// Inside the Bassin d'Arcachon the free wave models return the open-ocean sea
/// (2.5 m at the Eyrac jetty on 2026-10-31), which is not the water at the spot.
/// What *is* local and measured is the wind: the lagoon sea is a short, fetch-
/// limited wind sea, and its height and period follow from the wind speed and
/// the distance over which the wind blows.
///
/// **This is a model, not a measurement.** `Swell.source` is
/// `.windSeaEstimate`, the UI writes « houle estimée », and the sea temperature
/// is left `nil`: nothing here pretends to be an observation.
///
/// The formula is the standard fetch-limited SMB relation (deep water, fully
/// developed within the fetch):
///
///     Hs = 0.283 · (U²/g) · tanh(0.0125 · (gF/U²)^0.42)
///     Tp = 7.54 · (U/g)  · tanh(0.077  · (gF/U²)^0.25)
///
/// At 10 m/s over 3 km it gives ≈ 0.39 m and ≈ 2.4 s — a chop, which is what
/// the Bassin is on a windy day. The constants are the published SMB ones, not
/// fitted to this app.
enum WindSeaEstimator {
    /// Default fetch when a region has no measured one: the width of the
    /// eastern Bassin between the Eyrac jetty and the opposite shore.
    static let defaultFetchMeters: Double = 3000

    /// Estimated sea for `wind` over `fetchMeters`.
    ///
    /// A calm wind gives a flat sea, never `nil`: 0.0 m is a real, meaningful
    /// value here because it is computed from a real wind, and the source says
    /// it is an estimate.
    static func estimate(
        wind: Wind,
        fetchMeters: Double = defaultFetchMeters) -> Swell
    {
        let speed = max(wind.speed, 0) / 3.6 // km/h -> m/s
        let fetch = max(fetchMeters, 1)
        let gravity = 9.81

        guard speed > 0 else {
            return Swell(
                waveHeight: 0,
                period: 0,
                directionDegrees: wind.directionDegrees,
                seaSurfaceTemperature: nil,
                source: .windSeaEstimate)
        }

        let windTerm = speed * speed / gravity
        let fetchTerm = gravity * fetch / (speed * speed)
        let height = 0.283 * windTerm * tanh(0.0125 * pow(fetchTerm, 0.42))
        let period = 7.54 * (speed / gravity) * tanh(0.077 * pow(fetchTerm, 0.25))

        return Swell(
            waveHeight: (height * 100).rounded() / 100,
            period: (period * 10).rounded() / 10,
            directionDegrees: wind.directionDegrees,
            seaSurfaceTemperature: nil,
            source: .windSeaEstimate)
    }
}
