import EstranCore
import Foundation

/// One hourly marine sample: the swell used by the rules.
public struct MarineSample: Codable, Hashable, Sendable {
    public let time: Date
    public let swell: Swell

    public init(time: Date, swell: Swell) {
        self.time = time
        self.swell = swell
    }
}

/// Open-Meteo Marine response (`marine-api.open-meteo.com`).
///
/// Decoded separately from the domain so a malformed payload is rejected at the
/// boundary, with a test per field. Arrays carry `null` when the model has no
/// value for an hour: a missing wave is not a 0 m wave.
struct MarineResponse: Decodable {
    let hourly: MarineHourly
}

/// The `hourly` block of the payload. Arrays carry `null` when the model has no
/// value for an hour: a missing wave is not a 0 m wave.
struct MarineHourly: Decodable {
    let time: [String]
    let waveHeight: [Double?]
    let wavePeriod: [Double?]
    let waveDirection: [Double?]
    let seaSurfaceTemperature: [Double?]

    enum CodingKeys: String, CodingKey {
        case time
        case waveHeight = "wave_height"
        case wavePeriod = "wave_period"
        case waveDirection = "wave_direction"
        case seaSurfaceTemperature = "sea_surface_temperature"
    }
}
