import Foundation

/// Surf: usable wave height and period, favourable swell direction, light
/// offshore wind and a moving tide.
///
/// The §7.1 "Go when" conditions are hard gates: wave height and period ranges,
/// wind below 20 km/h and a known favourable direction are mandatory.
public struct SurfRule: ActivityRule {
    public let activity = Activity.surfing
    public let threshold = 0.65

    public static let waveRange = 0.8 ... 2.5
    public static let periodRange = 8.0 ... 14.0
    public static let maximumWindSpeed: Double = 20
    public static let maximumSwellDirectionError: Double = 90

    public init() {}

    public func blockers(_ conditions: Conditions) -> [ActivityBlocker] {
        var blockers: [ActivityBlocker] = []
        if RuleSignals.isStormy(conditions.weather) {
            blockers.append(.storm)
        }
        if conditions.swell.waveHeight < Self.waveRange.lowerBound {
            blockers.append(.waveTooSmall)
        }
        if conditions.swell.waveHeight > Self.waveRange.upperBound {
            blockers.append(.waveTooLarge)
        }
        if !Self.periodRange.contains(conditions.swell.period) {
            blockers.append(.wavePeriod)
        }
        if conditions.weather.wind.speed >= Self.maximumWindSpeed {
            blockers.append(.wind)
        }
        if let component = RuleSignals.onshoreComponent(conditions),
           component >= 0.5,
           conditions.weather.wind.speed >= 15
        {
            blockers.append(.onshoreWind)
        }

        var missingData = false
        if let orientation = conditions.spot.coastOrientationDegrees {
            let distance = ScoreMath.angularDistance(conditions.swell.directionDegrees, orientation)
            if distance > Self.maximumSwellDirectionError {
                blockers.append(.swellDirection)
            }
        } else {
            missingData = true
        }
        if conditions.tide.isRising == nil {
            missingData = true
        }
        if missingData {
            blockers.append(.dataUnavailable)
        }
        if RuleSignals.isBeyondValidityHorizon(conditions) {
            blockers.append(.dataUnavailable)
        }
        return blockers
    }

    public func score(_ conditions: Conditions) -> Double {
        let wave = ScoreMath.trapezoid(
            conditions.swell.waveHeight,
            full: 0.8 ... 2.5,
            zero: 0.4 ... 3.8)
        let period = ScoreMath.trapezoid(
            conditions.swell.period,
            full: 8 ... 14,
            zero: 5 ... 18)
        let speed = ScoreMath.linear(conditions.weather.wind.speed, zeroAt: 30, fullAt: 15)
        let direction: Double = if let component = RuleSignals.onshoreComponent(conditions) {
            (1 - component) / 2
        } else {
            0
        }
        let wind = ScoreMath.weighted([(speed, 0.6), (direction, 0.4)])

        let tide: Double = if conditions.tide.isRising == nil {
            0
        } else {
            conditions.tide.isSlack(at: conditions.at) ? 0.5 : 1
        }

        let swellDirection: Double
        if let orientation = conditions.spot.coastOrientationDegrees {
            let distance = ScoreMath.angularDistance(conditions.swell.directionDegrees, orientation)
            swellDirection = ScoreMath.linear(distance, zeroAt: 120, fullAt: 45)
        } else {
            swellDirection = 0
        }

        return ScoreMath.weighted([
            (wave, 0.35),
            (period, 0.20),
            (wind, 0.25),
            (tide, 0.10),
            (swellDirection, 0.10)
        ])
    }
}
