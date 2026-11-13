import Foundation

/// Low-precision solar position, accurate to a few minutes at our latitudes.
///
/// Used by the rules that need daylight without depending on a network
/// sunrise/sunset payload. The algorithm is the standard NOAA/Astronomical
/// Almanac approximation and is pure and deterministic.
public enum SolarDaylight {
    /// Solar elevation of the top of the sun at sunrise/sunset, in degrees.
    public static let horizonElevation = -0.833

    /// Solar elevation in degrees at `date` for `coordinate`.
    public static func solarElevationDegrees(at date: Date, coordinate: Coordinate) -> Double {
        let daysSinceJ2000 = date.timeIntervalSince1970 / 86400 + 2_440_587.5 - 2_451_545.0

        let meanLongitude = 280.460 + 0.985_647_4 * daysSinceJ2000
        let meanAnomaly = (357.528 + 0.985_600_3 * daysSinceJ2000) * .pi / 180
        let eclipticLongitude =
            (meanLongitude + 1.915 * sin(meanAnomaly) + 0.020 * sin(2 * meanAnomaly)) * .pi / 180
        let obliquity = (23.439 - 0.000_000_4 * daysSinceJ2000) * .pi / 180

        let declination = asin(sin(obliquity) * sin(eclipticLongitude))
        let rightAscension = atan2(cos(obliquity) * sin(eclipticLongitude), cos(eclipticLongitude))

        let greenwichSiderealTime =
            (280.460_618_37 + 360.985_647_366_29 * daysSinceJ2000)
                .truncatingRemainder(dividingBy: 360)
        let localSiderealTime = (greenwichSiderealTime + coordinate.longitude) * .pi / 180
        let hourAngle = localSiderealTime - rightAscension

        let latitude = coordinate.latitude * .pi / 180
        let elevation = asin(
            sin(latitude) * sin(declination)
                + cos(latitude) * cos(declination) * cos(hourAngle))
        return elevation * 180 / .pi
    }

    /// `true` when the sun is above the horizon (civil sunrise/sunset).
    public static func isDaylight(at date: Date, coordinate: Coordinate) -> Bool {
        solarElevationDegrees(at: date, coordinate: coordinate) > horizonElevation
    }

    /// `true` when any part of the uncertainty envelope around `date` is below
    /// the horizon.
    ///
    /// The conservative reading for **swimming only**: a tide prediction whose
    /// envelope could straddle sunset/sunrise is treated as night. The envelope
    /// is the uncertainty of the *tide*, so it says nothing about the sun
    /// (`W-NIGHTFIX`): the pêche à pied, boating and balade cautions read the
    /// plain instant, and a window reads the window's own span.
    public static func isNight(
        at date: Date,
        coordinate: Coordinate,
        uncertainty: TimeInterval = 0) -> Bool
    {
        let start = date.addingTimeInterval(-uncertainty)
        let end = date.addingTimeInterval(uncertainty)
        return !(isDaylight(at: start, coordinate: coordinate)
            && isDaylight(at: end, coordinate: coordinate))
    }

    /// `true` when any part of `window` is below the horizon.
    ///
    /// A window is a span of clock time, not a single instant: 16:00–19:00 in
    /// November starts in daylight and ends after sunset, and the reader needs
    /// the night caution for it. The span is sampled every `step`, so a window
    /// that straddles sunrise or sunset is caught whichever endpoint is dark.
    public static func isNight(
        in window: DateInterval,
        coordinate: Coordinate,
        step: TimeInterval = 5 * 60) -> Bool
    {
        guard window.duration > 0 else {
            return !isDaylight(at: window.start, coordinate: coordinate)
        }
        let count = Int(window.duration / step)
        for index in 0 ... count {
            let date = window.start.addingTimeInterval(Double(index) * step)
            if !isDaylight(at: date, coordinate: coordinate) {
                return true
            }
        }
        return !isDaylight(at: window.end, coordinate: coordinate)
    }
}
