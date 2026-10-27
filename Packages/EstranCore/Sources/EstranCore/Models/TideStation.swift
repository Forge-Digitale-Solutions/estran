import Foundation

/// Failures raised by the tide engine.
public enum TideError: Error, Equatable, Sendable {
    /// No station is registered under this identifier.
    case unknownStation(String)
    /// The station data cannot feed the prediction model.
    case invalidStation(String)
    /// The requested date is beyond the station's declared validity horizon.
    case outsideValidity(String)
}

/// One harmonic constituent of a tidal station.
///
/// The prediction model uses the standard form
/// `h(t) = Z0 + Σ H_i · cos(ω_i · t − g_i)`, where `t` is UTC time in hours
/// since the reference epoch, `H_i` is the amplitude in meters and `g_i` the
/// Greenwich phase lag in degrees.
public struct HarmonicConstituent: Codable, Hashable, Sendable {
    /// Standard symbol, e.g. `M2`, `S2`, `K1`.
    public let symbol: String
    /// Amplitude in meters.
    public let amplitude: Double
    /// Phase lag in degrees, used by the linear harmonic model.
    public let phaseDegrees: Double

    public init(symbol: String, amplitude: Double, phaseDegrees: Double) {
        self.symbol = symbol
        self.amplitude = amplitude
        self.phaseDegrees = phaseDegrees
    }

    /// Angular speed in degrees per hour, or `nil` for an unknown symbol.
    public var speedDegreesPerHour: Double? {
        ConstituentSpeeds.degreesPerHour(for: symbol)
    }
}

/// Reference angular speeds for the constituents supported by the engine.
///
/// These are astronomical constants (not station data) and are independent of
/// any provider licence.
public enum ConstituentSpeeds {
    /// Degrees per hour for every supported constituent symbol.
    public static let table: [String: Double] = [
        "SA": 0.041_068_6,
        "SSA": 0.082_137_3,
        "M2": 28.984_104_2,
        "S2": 30.0,
        "N2": 28.439_729_5,
        "K2": 30.082_137_3,
        "2N2": 27.895_354_8,
        "MU2": 27.968_208_4,
        "NU2": 28.512_583_1,
        "L2": 29.528_478_9,
        "T2": 29.958_933_3,
        "K1": 15.041_068_6,
        "O1": 13.943_035_6,
        "P1": 14.958_931_4,
        "Q1": 13.398_660_9,
        "2Q1": 12.854_286_2,
        "RHO1": 13.471_514_5,
        "M1": 14.496_693_9,
        "J1": 15.585_443_3,
        "OO1": 16.139_101_7,
        "S1": 15.0,
        "M4": 57.968_208_4,
        "MN4": 57.423_833_7,
        "MS4": 58.984_104_2,
        "M6": 86.952_312_7
    ]

    /// Degrees per hour for `symbol`, or `nil` when the symbol is unknown.
    public static func degreesPerHour(for symbol: String) -> Double? {
        table[symbol]
    }
}

/// Harmonic constants for one tide station.
///
/// A station carries its own constants: the Bassin d'Arcachon is a semi-enclosed
/// lagoon, so a generic ocean model is not accurate enough. Amplitudes and
/// phases must be expressed for the model epoch and the linear model used by
/// `HarmonicPredictor`; provider constants may need conversion before being
/// embedded.
public struct TidalStation: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let coordinate: Coordinate
    /// IANA identifier of the station's civil time zone.
    public let timezoneIdentifier: String
    /// Mean sea level above chart datum (`Z0`), in meters.
    public let meanSeaLevel: Double
    /// Fitted mean spring range in meters.
    ///
    /// This is **not** `nphma − npbma` (an extreme astronomical range). The
    /// baseline dataset computes it as `2 · (M2 + S2)` from the fitted
    /// constants; the generator may refine it with the full fitted spring
    /// range, but it must record the method in the dataset metadata.
    public let meanSpringRange: Double
    public let constituents: [HarmonicConstituent]
    /// Data attribution, e.g. `Source : REFMAR / Shom — Licence Ouverte 2.0`.
    public let attribution: String
    /// Last date for which the constants are declared valid.
    ///
    /// `nil` means the dataset does not declare a horizon (synthetic fixtures
    /// only). A released dataset must set it; `TideEngine` fails closed past it.
    public let validUntil: Date?
    /// Whether the constants already include nodal corrections.
    ///
    /// The baseline engine implements no `f`/`u` terms, so a station declaring
    /// `true` is rejected rather than silently mispredicted.
    public let nodalCorrections: Bool

    public init(
        id: String,
        name: String,
        coordinate: Coordinate,
        timezoneIdentifier: String,
        meanSeaLevel: Double,
        meanSpringRange: Double,
        constituents: [HarmonicConstituent],
        attribution: String,
        validUntil: Date? = nil,
        nodalCorrections: Bool = false)
    {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.timezoneIdentifier = timezoneIdentifier
        self.meanSeaLevel = meanSeaLevel
        self.meanSpringRange = meanSpringRange
        self.constituents = constituents
        self.attribution = attribution
        self.validUntil = validUntil
        self.nodalCorrections = nodalCorrections
    }

    /// Mean spring range derived from the two dominant semidiurnal amplitudes,
    /// `2 · (M2 + S2)`, or `nil` when either constituent is absent.
    ///
    /// The dataset generator must use this value (or a documented fitted
    /// equivalent) instead of `nphma − npbma`.
    public var derivedMeanSpringRange: Double? {
        guard let m2 = constituents.first(where: { $0.symbol == "M2" })?.amplitude,
              let s2 = constituents.first(where: { $0.symbol == "S2" })?.amplitude
        else {
            return nil
        }
        return 2 * (m2 + s2)
    }

    /// `true` when `date` is inside the declared validity horizon.
    public func isValid(at date: Date) -> Bool {
        guard let validUntil else { return true }
        return date <= validUntil
    }

    /// Civil time zone of the station, falling back to UTC for an unknown identifier.
    public var timezone: TimeZone {
        TimeZone(identifier: timezoneIdentifier) ?? .gmt
    }

    /// Returns the reason why the station cannot feed the prediction model, if any.
    public var validationError: TideError? {
        guard TimeZone(identifier: timezoneIdentifier) != nil else {
            return .invalidStation("invalid timezoneIdentifier \(timezoneIdentifier)")
        }
        guard meanSeaLevel.isFinite else {
            return .invalidStation("meanSeaLevel must be finite")
        }
        guard meanSpringRange.isFinite, meanSpringRange > 0 else {
            return .invalidStation("meanSpringRange must be finite and positive")
        }
        guard !nodalCorrections else {
            return .invalidStation("nodal corrections are not implemented; set nodalCorrections to false")
        }
        guard coordinate.latitude.isFinite,
              coordinate.longitude.isFinite,
              (-90.0 ... 90.0).contains(coordinate.latitude),
              (-180.0 ... 180.0).contains(coordinate.longitude)
        else {
            return .invalidStation("coordinate must be finite and within valid bounds")
        }
        guard !constituents.isEmpty else {
            return .invalidStation("constituents must not be empty")
        }
        var seen = Set<String>()
        for constituent in constituents {
            guard constituent.speedDegreesPerHour != nil else {
                return .invalidStation("unknown constituent \(constituent.symbol)")
            }
            guard constituent.amplitude.isFinite, constituent.amplitude >= 0 else {
                return .invalidStation("amplitude must be finite and non-negative for \(constituent.symbol)")
            }
            guard constituent.phaseDegrees.isFinite else {
                return .invalidStation("phase must be finite for \(constituent.symbol)")
            }
            guard seen.insert(constituent.symbol).inserted else {
                return .invalidStation("duplicate constituent \(constituent.symbol)")
            }
        }
        return nil
    }
}
