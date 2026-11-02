import Foundation

public struct Wind: Codable, Hashable, Sendable {
    public let speed: Double
    public let gust: Double
    public let directionDegrees: Double

    public init(speed: Double, gust: Double, directionDegrees: Double) {
        self.speed = speed
        self.gust = gust
        self.directionDegrees = directionDegrees
    }
}

public struct Swell: Codable, Hashable, Sendable {
    /// Where the wave values come from.
    ///
    /// `model` is a wave model that resolves the water at the spot. A
    /// `windSeaEstimate` is computed locally from the measured wind and a fetch
    /// length: it is a **model of the lagoon sea**, not an observation, and the
    /// UI says so. Nothing is ever `.estimate` on a spot the marine grid covers.
    public enum Source: String, Codable, Hashable, Sendable {
        case model
        case windSeaEstimate
    }

    public let waveHeight: Double
    public let period: Double
    public let directionDegrees: Double
    /// Sea surface temperature in Celsius, when available.
    public let seaSurfaceTemperature: Double?
    /// Provenance of the wave values.
    public let source: Source

    public var isEstimated: Bool {
        source == .windSeaEstimate
    }

    public init(
        waveHeight: Double,
        period: Double,
        directionDegrees: Double,
        seaSurfaceTemperature: Double? = nil,
        source: Source = .model)
    {
        self.waveHeight = waveHeight
        self.period = period
        self.directionDegrees = directionDegrees
        self.seaSurfaceTemperature = seaSurfaceTemperature
        self.source = source
    }

    /// Tolerates payloads written before `source` existed (fixtures, cached
    /// JSON): an absent value is a model value, never an estimate.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        waveHeight = try container.decode(Double.self, forKey: .waveHeight)
        period = try container.decode(Double.self, forKey: .period)
        directionDegrees = try container.decode(Double.self, forKey: .directionDegrees)
        seaSurfaceTemperature = try container.decodeIfPresent(
            Double.self, forKey: .seaSurfaceTemperature)
        source = try container.decodeIfPresent(Source.self, forKey: .source) ?? .model
    }
}

public enum WeatherCondition: String, Codable, Hashable, Sendable {
    case clear
    case partlyCloudy
    case cloudy
    case rain
    case showers
    case thunderstorm
    case fog
    case snow
    case unknown
}

public struct WeatherNow: Codable, Hashable, Sendable {
    public let temperature: Double
    public let condition: WeatherCondition
    /// Probability from 0 to 1.
    public let precipitationChance: Double
    /// Fraction from 0 to 1.
    public let cloudCover: Double
    public let wind: Wind
    /// Visibility in meters.
    public let visibility: Double

    public init(
        temperature: Double,
        condition: WeatherCondition,
        precipitationChance: Double,
        cloudCover: Double,
        wind: Wind,
        visibility: Double)
    {
        self.temperature = temperature
        self.condition = condition
        self.precipitationChance = precipitationChance
        self.cloudCover = cloudCover
        self.wind = wind
        self.visibility = visibility
    }
}

public struct Conditions: Codable, Hashable, Sendable {
    public let spot: Spot
    public let at: Date
    public let tide: TideState
    public let weather: WeatherNow
    public let swell: Swell

    public init(spot: Spot, at: Date, tide: TideState, weather: WeatherNow, swell: Swell) {
        self.spot = spot
        self.at = at
        self.tide = tide
        self.weather = weather
        self.swell = swell
    }
}
