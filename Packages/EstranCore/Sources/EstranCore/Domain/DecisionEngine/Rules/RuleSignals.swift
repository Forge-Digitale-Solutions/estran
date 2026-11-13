import Foundation

/// Shared signal interpretation used by several rules.
enum RuleSignals {
    /// Rain that forces a `Non` (owner decision 2026-11-12): franc rain or
    /// showers, or a high precipitation chance with an otherwise dry/unknown
    /// condition. Light rain (`.drizzle`) never blocks on its own.
    static func isRaining(_ weather: WeatherNow) -> Bool {
        switch weather.condition {
        case .rain, .showers:
            true
        case .thunderstorm:
            // Storm is its own blocker; a thunderstorm is never "just rain".
            false
        case .drizzle, .clear, .partlyCloudy, .cloudy, .fog, .snow, .unknown:
            weather.precipitationChance >= 0.8
        }
    }

    /// Light rain that lowers the score and adds a caution, without forcing a
    /// `Non`: drizzle, or a middling chance under a dry condition.
    static func isLightRain(_ weather: WeatherNow) -> Bool {
        switch weather.condition {
        case .drizzle:
            true
        case .rain, .showers, .thunderstorm:
            false
        case .clear, .partlyCloudy, .cloudy, .fog, .snow, .unknown:
            weather.precipitationChance >= 0.4 && weather.precipitationChance < 0.8
        }
    }

    /// Thunderstorm or storm-force gusts.
    static func isStormy(_ weather: WeatherNow) -> Bool {
        weather.condition == .thunderstorm || weather.wind.gust >= 70
    }

    /// `1` for a dry forecast, `0` when rain is likely. Drizzle is a small
    /// penalty, not a zero (owner decision 2026-11-12).
    static func precipitationScore(_ weather: WeatherNow) -> Double {
        switch weather.condition {
        case .rain, .showers, .thunderstorm:
            0
        case .drizzle:
            0.6
        case .clear, .partlyCloudy, .cloudy, .fog, .snow, .unknown:
            ScoreMath.linear(weather.precipitationChance, zeroAt: 0.8, fullAt: 0.1)
        }
    }

    /// Visibility converted to kilometers.
    static func visibilityKilometers(_ weather: WeatherNow) -> Double {
        weather.visibility / 1000
    }

    /// Seaward component of the wind, `1` onshore, `-1` offshore.
    static func onshoreComponent(_ conditions: Conditions) -> Double? {
        guard let orientation = conditions.spot.coastOrientationDegrees else { return nil }
        return ScoreMath.onshoreComponent(
            windDirection: conditions.weather.wind.directionDegrees,
            coastOrientation: orientation)
    }

    /// Score multiplier applied at night by the three activities that remain
    /// open after dark (owner decisions 2026-11-12 for pêche à pied and boating,
    /// 2026-11-13 for balade). Night never blocks them; it lowers the score a
    /// little and adds a caution.
    static let nightScorePenalty = 0.85

    /// `nightScorePenalty` when the **instant** is dark, `1` by day.
    ///
    /// The plain instant, no uncertainty envelope (`W-NIGHTFIX`): `u_t` is the
    /// uncertainty of the tide prediction, not of the clock, and the sun's
    /// position at a given instant is certain. Reading the envelope here put
    /// « De nuit » in broad daylight at 09:08 after an 08:20 sunrise.
    static func nightScoreMultiplier(_ conditions: Conditions) -> Double {
        let isNight = SolarDaylight.isNight(
            at: conditions.at,
            coordinate: conditions.spot.coordinate)
        return isNight ? nightScorePenalty : 1
    }

    /// `true` when the uncertainty interval reaches past the station's declared
    /// validity horizon.
    ///
    /// The gate reads the tide up to `at + u_t`, so the horizon must be checked
    /// there: checking only `at` would predict up to one envelope beyond the
    /// horizon, which is exactly what `validUntil` exists to prevent.
    static func isBeyondValidityHorizon(_ conditions: Conditions) -> Bool {
        guard let validUntil = conditions.tide.validUntil else { return false }
        let reach = conditions.at.addingTimeInterval(conditions.spot.uncertainty.timeInterval)
        return reach > validUntil
    }
}
