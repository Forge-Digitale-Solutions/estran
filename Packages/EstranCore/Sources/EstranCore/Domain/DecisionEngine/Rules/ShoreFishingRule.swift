import Foundation

/// Pêche à pied: a big coefficient, close to low water, light wind and no rain.
///
/// The §7.1 "Go when" conditions are hard gates: a high score cannot outvote a
/// coefficient below 72, a tide far from low water or a wind above 15 km/h.
///
/// **Night never blocks** (owner decision 2026-11-12). The score is multiplied
/// by `RuleSignals.nightScorePenalty` after dark and the verdict carries the
/// « lampe frontale » caution; a night high tide is still a `Non` from the
/// ordinary gates.
///
/// **Coefficient scale (review Z23).** The gate reads the *national* coefficient
/// computed at Brest (`range / 6.10 × 100`). The local proxy ran ≈ 17 % high on
/// 2025 (median 85.0 against a national 72.5), so a threshold of 70 on that
/// scale opened at a national coefficient of ≈ 60. The threshold is 72: the
/// 2-point margin absorbs the measured Brest scatter. Without the national
/// source the gate fails closed.
public struct ShoreFishingRule: ActivityRule {
    public let activity = Activity.shoreFishing
    public let threshold = 0.6

    /// Maximum distance to low water accepted by the gate, in minutes.
    public static let lowWaterWindowMinutes: Double = 120
    /// Maximum wind speed accepted by the gate, in km/h.
    public static let maximumWindSpeed: Double = 15
    /// Minimum national tide coefficient accepted by the gate.
    ///
    /// The local proxy ran ≈ 17 % high on 2025, so the previous 70 opened at a
    /// national coefficient of ≈ 60. 72 includes a 2-point margin for the
    /// measured Brest scatter (review Z23).
    public static let minimumCoefficient = 72

    public init() {}

    public func blockers(_ conditions: Conditions) -> [ActivityBlocker] {
        var blockers: [ActivityBlocker] = []
        if RuleSignals.isStormy(conditions.weather) {
            blockers.append(.storm)
        }
        if RuleSignals.isRaining(conditions.weather) {
            blockers.append(.rain)
        }
        if conditions.weather.wind.speed >= Self.maximumWindSpeed {
            blockers.append(.wind)
        }
        if conditions.tide.coefficientSource != .nationalBrest {
            // The gate is defined on the national scale; a local proxy would
            // open it ≈ 11 % too early.
            blockers.append(.dataUnavailable)
        } else if conditions.tide.coefficient < Self.minimumCoefficient {
            blockers.append(.coefficient)
        }
        let uncertainty = conditions.spot.uncertainty
        let start = conditions.at.addingTimeInterval(-uncertainty.timeInterval)
        let end = conditions.at.addingTimeInterval(uncertainty.timeInterval)
        if let maximumMinutes = conditions.tide.maximumMinutesFromNearestEvent(
            of: .low,
            from: start,
            to: end)
        {
            if maximumMinutes > Self.lowWaterWindowMinutes {
                let nominalMinutes = conditions.tide.minutesFromNearestEvent(of: .low, to: conditions.at)
                if let nominalMinutes, nominalMinutes <= Self.lowWaterWindowMinutes {
                    blockers.append(.insufficientMargin)
                } else {
                    blockers.append(.tideTiming)
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
        let coefficient = ScoreMath.linear(
            Double(conditions.tide.coefficient),
            zeroAt: 50,
            fullAt: 70)
        let uncertainty = conditions.spot.uncertainty
        let start = conditions.at.addingTimeInterval(-uncertainty.timeInterval)
        let end = conditions.at.addingTimeInterval(uncertainty.timeInterval)
        let lowWater: Double = if let minutes = conditions.tide.maximumMinutesFromNearestEvent(
            of: .low,
            from: start,
            to: end)
        {
            // Full credit within 60 minutes of low water, zero beyond 2h30.
            ScoreMath.linear(minutes, zeroAt: 150, fullAt: 60)
        } else {
            0
        }
        let wind = ScoreMath.linear(conditions.weather.wind.speed, zeroAt: 30, fullAt: 15)
        let rain = RuleSignals.precipitationScore(conditions.weather)

        return ScoreMath.weighted([
            (coefficient, 0.35),
            (lowWater, 0.30),
            (wind, 0.20),
            (rain, 0.15)
        ]) * RuleSignals.nightScoreMultiplier(conditions)
    }
}
