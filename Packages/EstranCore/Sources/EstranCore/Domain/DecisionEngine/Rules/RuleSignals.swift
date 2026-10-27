import Foundation

/// Shared signal interpretation used by several rules.
enum RuleSignals {
    /// Rain, showers, thunderstorm, or a high enough precipitation chance.
    static func isRaining(_ weather: WeatherNow) -> Bool {
        switch weather.condition {
        case .rain, .showers, .thunderstorm:
            true
        default:
            weather.precipitationChance >= 0.6
        }
    }

    /// Thunderstorm or storm-force gusts.
    static func isStormy(_ weather: WeatherNow) -> Bool {
        weather.condition == .thunderstorm || weather.wind.gust >= 70
    }

    /// `1` for a dry forecast, `0` when rain is likely.
    static func precipitationScore(_ weather: WeatherNow) -> Double {
        switch weather.condition {
        case .rain, .showers, .thunderstorm:
            0
        default:
            ScoreMath.linear(weather.precipitationChance, zeroAt: 0.6, fullAt: 0.1)
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
