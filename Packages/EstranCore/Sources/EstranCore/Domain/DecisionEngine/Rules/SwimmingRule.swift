import Foundation

/// Baignade: warm enough water and air, light wind, small swell, daylight and
/// no strong pass current.
///
/// The §7.1 "Go when" conditions are hard safety gates: water below 18 °C, air
/// below 20 °C, wind at or above 20 km/h, swell at or above 0.8 m, night or a
/// strong current force a `Non`. A missing sea-surface temperature is
/// `.dataUnavailable` and does not mute the current level; a missing range or
/// calibration is `.currentDataUnavailable` (the level is « Courants non
/// estimés »). A missing phase falls back to moderate/low, never to a false
/// `low` inside the grey band.
///
/// **Current level (review v11).** The current in the passes follows the
/// **local predicted tidal range**, not the national coefficient. `strong` at
/// or above `spot.swimmingRange.strongAt` with the phase in 0.4...0.6;
/// `moderate` at or above `lowBelow` (the ±0.30 m grey band, whatever the
/// phase); `low` otherwise. A missing range or calibration is
/// `.currentDataUnavailable`, so the UI shows « Courants non estimés », never
/// « faibles ». The level is a presentation input only: the swimming card never
/// shows a `Oui`.
public struct SwimmingRule: ActivityRule {
    public let activity = Activity.swimming
    public let threshold = 0.65

    public static let minimumWaterTemperature: Double = 18
    public static let minimumAirTemperature: Double = 20
    public static let maximumWindSpeed: Double = 20
    public static let maximumSwellHeight: Double = 0.8
    /// Tide-phase band treated as a strong pass current (mid-tide, not slack).
    public static let strongCurrentBand: ClosedRange<Double> = 0.4 ... 0.6

    public init() {}

    public func blockers(_ conditions: Conditions) -> [ActivityBlocker] {
        weatherBlockers(conditions) + currentBlockers(conditions)
    }

    private func weatherBlockers(_ conditions: Conditions) -> [ActivityBlocker] {
        var blockers: [ActivityBlocker] = []
        if RuleSignals.isStormy(conditions.weather) {
            blockers.append(.storm)
        }
        if let waterTemperature = conditions.swell.seaSurfaceTemperature {
            if waterTemperature < Self.minimumWaterTemperature {
                blockers.append(.waterTemperature)
            }
        } else {
            blockers.append(.dataUnavailable)
        }
        if conditions.weather.temperature < Self.minimumAirTemperature {
            blockers.append(.temperature)
        }
        if conditions.weather.wind.speed >= Self.maximumWindSpeed {
            blockers.append(.wind)
        }
        if conditions.swell.waveHeight >= Self.maximumSwellHeight {
            blockers.append(.swellTooLarge)
        }
        if !isDaylight(conditions) {
            blockers.append(.night)
        }
        return blockers
    }

    private func currentBlockers(_ conditions: Conditions) -> [ActivityBlocker] {
        var blockers: [ActivityBlocker] = []
        switch currentRisk(conditions) {
        case .strong:
            blockers.append(.strongCurrent)
        case .moderate:
            // The grey band: at least moderate, never « faibles ».
            blockers.append(.insufficientMargin)
        case .unknown:
            // The current level is unknown, but a missing sea temperature is
            // `.dataUnavailable` and must not mute it (review v9 / M2 risk).
            blockers.append(.currentDataUnavailable)
        case .low:
            break
        }
        if RuleSignals.isBeyondValidityHorizon(conditions) {
            blockers.append(.currentDataUnavailable)
        }
        return blockers
    }

    public func score(_ conditions: Conditions) -> Double {
        let water: Double = if let waterTemperature = conditions.swell.seaSurfaceTemperature {
            ScoreMath.linear(waterTemperature, zeroAt: 16, fullAt: 18)
        } else {
            0
        }
        let air = ScoreMath.linear(conditions.weather.temperature, zeroAt: 12, fullAt: 20)
        let wind = ScoreMath.linear(conditions.weather.wind.speed, zeroAt: 35, fullAt: 20)
        let swell = ScoreMath.linear(conditions.swell.waveHeight, zeroAt: 1.5, fullAt: 0.8)
        let daylight: Double = isDaylight(conditions) ? 1 : 0
        let current: Double = switch currentRisk(conditions) {
        case .low:
            1
        case .moderate:
            0.5
        case .strong, .unknown:
            0.2
        }

        return ScoreMath.weighted([
            (water, 0.25),
            (air, 0.20),
            (wind, 0.20),
            (swell, 0.20),
            (daylight, 0.10),
            (current, 0.05)
        ])
    }

    private func isDaylight(_ conditions: Conditions) -> Bool {
        !SolarDaylight.isNight(
            at: conditions.at,
            coordinate: conditions.spot.coordinate,
            uncertainty: conditions.spot.uncertainty.timeInterval)
    }

    /// Pass-current level from the local predicted range and the tide phase.
    private enum CurrentRisk {
        /// Below the grey band: the current gate does not apply.
        case low
        /// Inside the ±0.30 m grey band, whatever the phase.
        case moderate
        /// At or above `strongAt` and mid-tide: the current is strong.
        case strong
        /// Missing range, phase or calibration: fail closed, never « faibles ».
        case unknown
    }

    private func currentRisk(_ conditions: Conditions) -> CurrentRisk {
        guard let swimmingRange = conditions.spot.swimmingRange,
              swimmingRange.isValid,
              let range = conditions.tide.dailyRange
        else {
            return .unknown
        }
        // The level is a pure function of the local range and the phase. A
        // missing phase cannot make a high range « low »: it falls back to
        // moderate, exactly as the grey band requires.
        if let phase = conditions.tide.progress(at: conditions.at),
           range >= swimmingRange.strongAt,
           Self.strongCurrentBand.contains(phase)
        {
            return .strong
        }
        if range >= swimmingRange.lowBelow {
            return .moderate
        }
        return .low
    }
}
