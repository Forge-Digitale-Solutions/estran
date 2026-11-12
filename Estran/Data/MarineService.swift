import EstranCore
import Foundation
import OSLog

/// Open-Meteo Marine: wave height, period, direction and sea-surface
/// temperature. Free, keyless, no account — the only runtime network call of the
/// app besides WeatherKit (`ARCHITECTURE_PLAN.md` §9.2).
///
/// **Fail closed.** A `null` wave height, period or direction means the hour has
/// no swell: the sample is dropped, never filled with `0`. A dropped hour makes
/// that forecast slot unavailable, never favourable.
///
/// **The model is gridded offshore.** Inside the Bassin d'Arcachon it returns
/// open-ocean swell (≈ 2.5 m at the Eyrac jetty), which is not the water at the
/// spot. `MarinePolicy` decides per spot whether the model is usable; this
/// service never guesses.
actor MarineService {
    private static let endpoint = "https://marine-api.open-meteo.com/v1/marine"
    private static let logger = Logger(subsystem: "com.forgedigitale.estran", category: "marine")

    private let session: URLSession
    private let cache: MarineCache

    init(session: URLSession = .shared, cache: MarineCache = MarineCache()) {
        self.session = session
        self.cache = cache
    }

    /// Hourly samples for `spot`, oldest first. Cached for 30 minutes.
    func samples(for spot: Spot, now: Date = Date()) async throws -> [MarineSample] {
        if let cached = await cache.samples(for: spot.id, now: now) {
            return cached
        }
        let data = try await fetch(spot)
        let samples = try Self.decode(data)
        guard !samples.isEmpty else {
            throw ConditionsProviderError.marineUnavailable
        }
        await cache.store(samples, for: spot.id, now: now)
        return samples
    }

    /// The point the marine grid is sampled at: the spot's dedicated marine point
    /// when it has one (Pointe de Grave samples the ocean beach, not its estuary
    /// coordinate), otherwise the spot's own coordinate.
    static func marineCoordinate(for spot: Spot) -> Coordinate {
        spot.marineCoordinate ?? spot.coordinate
    }

    /// The Open-Meteo Marine request URL for a spot, extracted so the coordinate
    /// selection is unit-testable without a network call.
    static func requestURL(for spot: Spot) -> URL? {
        let point = marineCoordinate(for: spot)
        var components = URLComponents(string: endpoint)
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(point.latitude)),
            URLQueryItem(name: "longitude", value: String(point.longitude)),
            URLQueryItem(
                name: "hourly",
                value: "wave_height,wave_period,wave_direction,sea_surface_temperature"),
            // UTC so the timestamps are unambiguous; the spot's time zone is
            // applied when a date is displayed, never when it is stored.
            URLQueryItem(name: "timezone", value: "UTC"),
            URLQueryItem(name: "forecast_days", value: "2")
        ]
        return components?.url
    }

    private func fetch(_ spot: Spot) async throws -> Data {
        guard let url = Self.requestURL(for: spot) else {
            throw ConditionsProviderError.marineUnavailable
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                throw ConditionsProviderError.marineUnavailable
            }
            return data
        } catch let error as ConditionsProviderError {
            throw error
        } catch {
            Self.logger.error("marine fetch failed: \(error.localizedDescription, privacy: .public)")
            throw ConditionsProviderError.marineUnavailable
        }
    }

    /// Maps the payload to `MarineSample`, dropping any hour whose wave data is
    /// incomplete. `seaSurfaceTemperature` is optional by domain contract: a
    /// missing sea temperature is a visible « eau indisponible », not a `0 °C`.
    static func decode(_ data: Data, timeZone: TimeZone = .gmt) throws -> [MarineSample] {
        let response: MarineResponse
        do {
            response = try JSONDecoder().decode(MarineResponse.self, from: data)
        } catch {
            throw ConditionsProviderError.marineUnavailable
        }

        let hourly = response.hourly
        let count = hourly.time.count
        guard count > 0,
              hourly.waveHeight.count >= count,
              hourly.wavePeriod.count >= count,
              hourly.waveDirection.count >= count,
              hourly.seaSurfaceTemperature.count >= count
        else {
            throw ConditionsProviderError.marineUnavailable
        }

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = timeZone
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm"

        var samples: [MarineSample] = []
        samples.reserveCapacity(count)
        for index in 0 ..< count {
            guard let date = parser.date(from: hourly.time[index]),
                  let height = hourly.waveHeight[index],
                  let period = hourly.wavePeriod[index],
                  let direction = hourly.waveDirection[index]
            else {
                // No swell for this hour. Dropping it keeps the forecast honest;
                // filling it would create a fake calm sea.
                continue
            }
            samples.append(
                MarineSample(
                    time: date,
                    swell: Swell(
                        waveHeight: height,
                        period: period,
                        directionDegrees: direction,
                        seaSurfaceTemperature: hourly.seaSurfaceTemperature[index])))
        }
        return samples
    }
}
