@testable import EstranCore
import Foundation

/// Synthetic tidal stations, built only from invented amplitude/phase values.
///
/// SYNTHETIC TEST FIXTURES — not SHOM data, and never ship these constants as
/// production or licensed values.
enum TideFixtures {
    /// Single-constituent (M2 only) synthetic station, aligned on UTC so the
    /// local day is a plain 24-hour UTC day in every test.
    ///
    /// `Z0 = 2.0 m`, `H(M2) = 2.5 m` → heights span exactly −0.5...4.5 m and
    /// the M2-only day range is exactly 4.0 m for every full UTC day.
    static let syntheticM2Station: TidalStation = .init(
        id: "synthetic-m2",
        name: "Synthetic M2 Station",
        coordinate: Coordinate(latitude: 0, longitude: 0),
        timezoneIdentifier: "UTC",
        meanSeaLevel: 2.0,
        meanSpringRange: 5.0,
        constituents: [HarmonicConstituent(symbol: "M2", amplitude: 2.5, phaseDegrees: 0)],
        attribution: "Synthetic test fixture")

    /// Same curve as `syntheticM2Station` but with an oversized mean spring
    /// range, so the raw coefficient falls below 20 and gets clamped.
    static let syntheticWideRangeStation: TidalStation = .init(
        id: "synthetic-wide-range",
        name: "Synthetic Wide Range Station",
        coordinate: Coordinate(latitude: 0, longitude: 0),
        timezoneIdentifier: "UTC",
        meanSeaLevel: 2.0,
        meanSpringRange: 40.0,
        constituents: syntheticM2Station.constituents,
        attribution: "Synthetic test fixture")

    /// Same curve as `syntheticM2Station` but with an undersized mean spring
    /// range, so the raw coefficient exceeds 120 and gets clamped.
    static let syntheticNarrowRangeStation: TidalStation = .init(
        id: "synthetic-narrow-range",
        name: "Synthetic Narrow Range Station",
        coordinate: Coordinate(latitude: 0, longitude: 0),
        timezoneIdentifier: "UTC",
        meanSeaLevel: 2.0,
        meanSpringRange: 3.0,
        constituents: syntheticM2Station.constituents,
        attribution: "Synthetic test fixture")

    /// Five-constituent synthetic station used to cross-check the harmonic sum
    /// against an independent reference implementation.
    static let syntheticMixedStation: TidalStation = .init(
        id: "synthetic-mixed",
        name: "Synthetic Mixed Station",
        coordinate: Coordinate(latitude: 44.66, longitude: -1.17),
        timezoneIdentifier: "Europe/Paris",
        meanSeaLevel: 2.3,
        meanSpringRange: 3.0,
        constituents: [
            HarmonicConstituent(symbol: "M2", amplitude: 1.7, phaseDegrees: 120),
            HarmonicConstituent(symbol: "S2", amplitude: 0.6, phaseDegrees: 150),
            HarmonicConstituent(symbol: "N2", amplitude: 0.35, phaseDegrees: 100),
            HarmonicConstituent(symbol: "K1", amplitude: 0.4, phaseDegrees: 90),
            HarmonicConstituent(symbol: "O1", amplitude: 0.25, phaseDegrees: 60)
        ],
        attribution: "Synthetic test fixture")

    /// Fails `TidalStation.validationError` (negative amplitude), for the
    /// invalid-station code paths.
    static let syntheticInvalidStation: TidalStation = .init(
        id: "synthetic-invalid",
        name: "Synthetic Invalid Station",
        coordinate: Coordinate(latitude: 0, longitude: 0),
        timezoneIdentifier: "UTC",
        meanSeaLevel: 2.0,
        meanSpringRange: 5.0,
        constituents: [HarmonicConstituent(symbol: "M2", amplitude: -2.5, phaseDegrees: 0)],
        attribution: "Synthetic test fixture")

    /// M2 angular speed from the astronomical constants table.
    static var m2SpeedDegreesPerHour: Double {
        guard let speed = ConstituentSpeeds.degreesPerHour(for: "M2") else {
            fatalError("M2 is missing from the constituent speed table")
        }
        return speed
    }

    /// M2 period in hours implied by the constants table.
    static var m2PeriodHours: Double {
        360 / m2SpeedDegreesPerHour
    }

    /// Date at exactly `hours` hours after the model epoch
    /// (`2000-01-01T00:00:00Z`), so M2 extrema line up exactly at multiples of
    /// the M2 period.
    static func date(hoursAfterModelEpoch hours: Double) -> Date {
        HarmonicPredictor.epoch.addingTimeInterval(hours * 3600)
    }

    /// Parses an ISO-8601 UTC instant, e.g. `"2025-06-01T04:00:00Z"`.
    static func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: iso) else {
            fatalError("Unparsable fixture ISO date: \(iso)")
        }
        return date
    }
}
