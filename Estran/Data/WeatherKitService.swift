import CoreLocation
import EstranCore
import Foundation

#if canImport(WeatherKit)
    import WeatherKit
#endif

/// Air weather from Apple WeatherKit.
///
/// **Entitlement.** WeatherKit needs the `com.apple.developer.weatherkit`
/// capability on the App ID and a build signed by a developer team
/// (`BUILD.md` §2). Without it every call fails and this service throws
/// `.weatherUnavailable`: the app then shows « Données indisponibles » instead
/// of a fabricated verdict (`AGENTS.md` invariants 3 and 4).
///
/// **No caching here.** `LiveConditionsProvider` owns the TTL cache, so this
/// stays a pure adapter.
public actor WeatherKitService: WeatherSource {
    public init() {}

    public func weather(for spot: Spot, at date: Date) async throws -> WeatherNow {
        #if canImport(WeatherKit)
            let (current, hourly) = try await fetch(for: spot)
            // `CurrentWeather` carries no precipitation chance; the hourly
            // sample covering the same hour does. When that hour is missing the
            // current conditions are not usable: fail closed rather than
            // pretend there is 0 % chance of rain.
            guard let hour = Self.matchingHour(hourly, date: date) else {
                throw ConditionsProviderError.weatherUnavailable
            }
            return Self.mapCurrent(current, precipitationChance: hour.precipitationChance)
        #else
            throw ConditionsProviderError.weatherUnavailable
        #endif
    }

    public func forecast(for spot: Spot, from date: Date, hours: Int) async throws -> [WeatherNow] {
        #if canImport(WeatherKit)
            let (_, hourly) = try await fetch(for: spot)
            // WeatherKit returns whole hours from the current one; keep the
            // samples at or after `date`, up to `hours`, in order.
            let selected = hourly.forecast
                .filter { $0.date >= date.addingTimeInterval(-3600) }
                .prefix(max(hours, 0))
                .map(Self.mapHour)
            guard !selected.isEmpty else { throw ConditionsProviderError.weatherUnavailable }
            return Array(selected)
        #else
            throw ConditionsProviderError.weatherUnavailable
        #endif
    }

    #if canImport(WeatherKit)
        private func fetch(for spot: Spot) async throws -> (CurrentWeather, Forecast<HourWeather>) {
            do {
                let weather = try await WeatherService.shared.weather(
                    for: CLLocation(
                        latitude: spot.coordinate.latitude,
                        longitude: spot.coordinate.longitude))
                return (weather.currentWeather, weather.hourlyForecast)
            } catch {
                // Authorisation, quota, network: the caller only needs to know
                // that the air weather is not available, never a neutral value.
                throw ConditionsProviderError.weatherUnavailable
            }
        }

        private static func mapCurrent(
            _ current: CurrentWeather,
            precipitationChance: Double) -> WeatherNow
        {
            WeatherNow(
                temperature: current.temperature.converted(to: .celsius).value,
                condition: map(current.condition),
                precipitationChance: precipitationChance,
                cloudCover: current.cloudCover,
                wind: Wind(
                    speed: current.wind.speed.converted(to: .kilometersPerHour).value,
                    gust: (current.wind.gust ?? current.wind.speed)
                        .converted(to: .kilometersPerHour).value,
                    directionDegrees: current.wind.direction.converted(to: .degrees).value),
                visibility: current.visibility.converted(to: .meters).value)
        }

        private static func mapHour(_ hour: HourWeather) -> WeatherNow {
            WeatherNow(
                temperature: hour.temperature.converted(to: .celsius).value,
                condition: map(hour.condition),
                precipitationChance: hour.precipitationChance,
                cloudCover: hour.cloudCover,
                wind: Wind(
                    speed: hour.wind.speed.converted(to: .kilometersPerHour).value,
                    gust: (hour.wind.gust ?? hour.wind.speed)
                        .converted(to: .kilometersPerHour).value,
                    directionDegrees: hour.wind.direction.converted(to: .degrees).value),
                visibility: hour.visibility.converted(to: .meters).value)
        }

        /// The hourly sample whose hour contains `date`, if any.
        private static func matchingHour(
            _ forecast: Forecast<HourWeather>,
            date: Date) -> HourWeather?
        {
            forecast.forecast.first {
                date >= $0.date && date < $0.date.addingTimeInterval(3600)
            }
        }

        /// WeatherKit has 33 conditions, the domain has 9. Every mapping is
        /// explicit; anything not listed becomes `.unknown`, which the rules
        /// treat as ordinary weather, never as a favourable signal.
        private static func map(_ condition: WeatherKit.WeatherCondition) -> EstranCore.WeatherCondition {
            switch condition {
            case .clear, .hot, .frigid, .blowingDust, .smoky:
                .clear
            case .mostlyClear, .partlyCloudy, .breezy, .windy:
                .partlyCloudy
            case .cloudy, .mostlyCloudy, .haze:
                .cloudy
            case .rain, .heavyRain, .freezingRain, .sunShowers, .drizzle,
                 .freezingDrizzle, .wintryMix:
                .rain
            case .scatteredThunderstorms, .isolatedThunderstorms,
                 .thunderstorms, .strongStorms, .tropicalStorm, .hurricane:
                .thunderstorm
            case .foggy:
                .fog
            case .snow, .heavySnow, .blowingSnow, .flurries, .sunFlurries, .sleet, .blizzard:
                .snow
            default:
                .unknown
            }
        }
    #endif
}
