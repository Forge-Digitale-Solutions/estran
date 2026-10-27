import Foundation

/// Bateau: moderate wind, small swell, enough water and good visibility.
///
/// The §7.1 "Go when" conditions are hard gates: swell at or above 1 m, wind at
/// or above 20 km/h, missing water height or insufficient draught force a `Non`.
public struct BoatingRule: ActivityRule {
    public let activity = Activity.boating
    public let threshold = 0.6

    /// Conservative draught applied when a spot does not declare its minimum
    /// water height. It is not a neutral value.
    public static let defaultMinimumWaterHeight = 0.5
    public static let maximumWindSpeed: Double = 20
    public static let maximumSwellHeight: Double = 1.0
    public static let minimumVisibilityKilometers: Double = 0.5

    public init() {}

    public func blockers(_ conditions: Conditions) -> [ActivityBlocker] {
        var blockers: [ActivityBlocker] = []
        if RuleSignals.isStormy(conditions.weather) {
            blockers.append(.storm)
        }
        if conditions.weather.condition == .fog {
            blockers.append(.fog)
        }
        if conditions.weather.wind.speed >= Self.maximumWindSpeed {
            blockers.append(.wind)
        }
        if conditions.swell.waveHeight >= Self.maximumSwellHeight {
            blockers.append(.swellTooLarge)
        }
        if RuleSignals.visibilityKilometers(conditions.weather) < Self.minimumVisibilityKilometers {
            blockers.append(.visibility)
        }
        let minimum = minimumWaterHeight(conditions)
        let uncertainty = conditions.spot.uncertainty
        let start = conditions.at.addingTimeInterval(-uncertainty.timeInterval)
        let end = conditions.at.addingTimeInterval(uncertainty.timeInterval)
        if let minimumHeight = conditions.tide.minimumHeight(from: start, to: end) {
            let conservativeHeight = minimumHeight - uncertainty.heightMeters
            if conservativeHeight < minimum {
                if let nominal = conditions.tide.height(at: conditions.at), nominal >= minimum {
                    blockers.append(.insufficientMargin)
                } else {
                    blockers.append(.waterLevel)
                }
            }
        } else {
            blockers.append(.dataUnavailable)
        }
        if RuleSignals.isBeyondValidityHorizon(conditions) {
            blockers.append(.dataUnavailable)
        }
        return blockers
    }

    public func score(_ conditions: Conditions) -> Double {
        let wind = ScoreMath.trapezoid(
            conditions.weather.wind.speed,
            full: 5 ... 20,
            zero: 0 ... 25)
        let swell = ScoreMath.linear(conditions.swell.waveHeight, zeroAt: 1.5, fullAt: 0.8)

        let water: Double
        let minimum = minimumWaterHeight(conditions)
        let uncertainty = conditions.spot.uncertainty
        let start = conditions.at.addingTimeInterval(-uncertainty.timeInterval)
        let end = conditions.at.addingTimeInterval(uncertainty.timeInterval)
        if let minimumHeight = conditions.tide.minimumHeight(from: start, to: end) {
            let conservativeHeight = minimumHeight - uncertainty.heightMeters
            water = ScoreMath.linear(conservativeHeight, zeroAt: minimum - 0.5, fullAt: minimum)
        } else {
            water = 0
        }

        let visibility: Double = if conditions.weather.condition == .fog {
            0
        } else {
            ScoreMath.linear(
                RuleSignals.visibilityKilometers(conditions.weather),
                zeroAt: 1,
                fullAt: 8)
        }

        return ScoreMath.weighted([
            (wind, 0.35),
            (swell, 0.30),
            (water, 0.20),
            (visibility, 0.15)
        ])
    }

    private func minimumWaterHeight(_ conditions: Conditions) -> Double {
        conditions.spot.minimumWaterHeight ?? Self.defaultMinimumWaterHeight
    }
}
