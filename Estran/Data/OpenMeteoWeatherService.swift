import EstranCore
import Foundation
import OSLog

/// Air weather from Open-Meteo (`api.open-meteo.com/v1/forecast`), the keyless
/// companion of the marine source.
///
/// It is the **fallback** of `FallbackWeatherSource`, used when WeatherKit is not
/// available (capability not enabled, unsigned build, quota). Same contract, same
/// fail-closed rule: an hour without every field is dropped, never filled.
///
/// `current` has no precipitation probability in the Open-Meteo API, so the
/// hourly sample covering the requested instant is used for it — the same
/// approach as the WeatherKit adapter.
struct OpenMeteoWeatherService: WeatherSource {
    /// CC BY 4.0: the fallback's values are credited on every surface that
    /// shows them (`WeatherAttributionStore`).
    let kind: WeatherSourceKind? = .openMeteo

    private static let endpoint = "https://api.open-meteo.com/v1/forecast"
    private static let logger = Logger(subsystem: "com.forgedigitalesolutions.estran", category: "weather")

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func weather(for spot: Spot, at date: Date) async throws -> WeatherNow {
        let samples = try await fetch(spot)
        guard let sample = samples.first(where: { sample in
            date >= sample.time && date < sample.time.addingTimeInterval(3600)
        }) else {
            throw ConditionsProviderError.weatherUnavailable
        }
        return sample.weather
    }

    func forecast(for spot: Spot, from date: Date, hours: Int) async throws -> [WeatherNow] {
        let samples = try await fetch(spot)
            .filter { $0.time >= date.addingTimeInterval(-3600) }
            .prefix(max(hours, 0))
        guard !samples.isEmpty else { throw ConditionsProviderError.weatherUnavailable }
        return samples.map(\.weather)
    }

    // MARK: - Transport

    /// One request covers current and forecast: the hourly block starts at the
    /// current hour, so the first sample is "now".
    private func fetch(_ spot: Spot) async throws -> [WeatherSample] {
        var components = URLComponents(string: Self.endpoint)
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(spot.coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(spot.coordinate.longitude)),
            URLQueryItem(
                name: "hourly",
                value: [
                    "temperature_2m", "weather_code", "precipitation_probability",
                    "cloud_cover", "wind_speed_10m", "wind_gusts_10m",
                    "wind_direction_10m", "visibility"
                ].joined(separator: ",")),
            URLQueryItem(name: "timezone", value: "UTC"),
            URLQueryItem(name: "forecast_days", value: "2"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh")
        ]
        guard let url = components?.url else {
            throw ConditionsProviderError.weatherUnavailable
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                throw ConditionsProviderError.weatherUnavailable
            }
            return try Self.decode(data)
        } catch let error as ConditionsProviderError {
            throw error
        } catch {
            Self.logger.error("open-meteo weather failed: \(error.localizedDescription, privacy: .public)")
            throw ConditionsProviderError.weatherUnavailable
        }
    }

    // MARK: - Decoding

    /// Hourly sample, kept separate from the domain so a missing value can be
    /// detected before a `WeatherNow` is built.
    struct WeatherSample: Equatable {
        let time: Date
        let weather: WeatherNow
    }

    static func decode(_ data: Data, timeZone: TimeZone = .gmt) throws -> [WeatherSample] {
        let response: Response
        do {
            response = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw ConditionsProviderError.weatherUnavailable
        }

        let hourly = response.hourly
        guard Self.isComplete(hourly) else {
            throw ConditionsProviderError.weatherUnavailable
        }
        let count = hourly.time.count

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = timeZone
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm"

        var samples: [WeatherSample] = []
        samples.reserveCapacity(count)
        for index in 0 ..< count {
            guard let date = parser.date(from: hourly.time[index]),
                  let temperature = hourly.temperature[index],
                  let code = hourly.weatherCode[index],
                  let chance = hourly.precipitationChance[index],
                  let clouds = hourly.cloudCover[index],
                  let speed = hourly.windSpeed[index],
                  let gust = hourly.windGusts[index],
                  let direction = hourly.windDirection[index],
                  let visibility = hourly.visibility[index]
            else {
                continue
            }
            samples.append(
                WeatherSample(
                    time: date,
                    weather: WeatherNow(
                        temperature: temperature,
                        condition: condition(forWMO: code),
                        precipitationChance: chance / 100,
                        cloudCover: clouds / 100,
                        wind: Wind(speed: speed, gust: gust, directionDegrees: direction),
                        visibility: visibility)))
        }
        return samples
    }

    /// Every hourly array must be as long as `time`: a short array would hide
    /// missing values behind `count`.
    private static func isComplete(_ hourly: OpenMeteoHourly) -> Bool {
        let count = hourly.time.count
        guard count > 0 else { return false }
        return hourly.temperature.count >= count
            && hourly.weatherCode.count >= count
            && hourly.precipitationChance.count >= count
            && hourly.cloudCover.count >= count
            && hourly.windSpeed.count >= count
            && hourly.windGusts.count >= count
            && hourly.windDirection.count >= count
            && hourly.visibility.count >= count
    }

    /// WMO 4677 weather code → the domain's ten conditions.
    ///
    /// Every branch is explicit; an unmapped code is `.unknown`, which the rules
    /// treat as ordinary weather, never as a favourable signal. Drizzle (51–57)
    /// and slight rain (61) are light; moderate/heavy rain (63/65) is franc;
    /// showers (80–82) are averses (owner decision 2026-11-12).
    static func condition(forWMO code: Int) -> EstranCore.WeatherCondition {
        switch code {
        case 0, 1:
            .clear
        case 2:
            .partlyCloudy
        case 3:
            .cloudy
        case 45, 48:
            .fog
        case 51, 53, 55, 56, 57, 61:
            .drizzle
        case 63, 65, 66, 67:
            .rain
        case 80, 81, 82:
            .showers
        case 71, 73, 75, 77, 85, 86:
            .snow
        case 95, 96, 99:
            .thunderstorm
        default:
            .unknown
        }
    }

    private struct Response: Decodable {
        let hourly: OpenMeteoHourly
    }
}

/// The `hourly` block of the Open-Meteo forecast payload.
struct OpenMeteoHourly: Decodable {
    let time: [String]
    let temperature: [Double?]
    let weatherCode: [Int?]
    let precipitationChance: [Double?]
    let cloudCover: [Double?]
    let windSpeed: [Double?]
    let windGusts: [Double?]
    let windDirection: [Double?]
    let visibility: [Double?]

    enum CodingKeys: String, CodingKey {
        case time
        case temperature = "temperature_2m"
        case weatherCode = "weather_code"
        case precipitationChance = "precipitation_probability"
        case cloudCover = "cloud_cover"
        case windSpeed = "wind_speed_10m"
        case windGusts = "wind_gusts_10m"
        case windDirection = "wind_direction_10m"
        case visibility
    }
}
