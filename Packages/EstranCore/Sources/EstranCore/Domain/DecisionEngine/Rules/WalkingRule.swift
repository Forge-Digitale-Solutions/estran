import Foundation

/// Balade: dry, not too windy, comfortable temperature.
///
/// The §7.1 "Go when" conditions are comfort gates: wind at or above 30 km/h, a
/// temperature outside 8...30 °C or franc rain force a `Non`. Light rain or
/// drizzle is a small score penalty, never a blocker (owner decision
/// 2026-11-12).
///
/// **Night never blocks** (owner decision 2026-11-13, same treatment as pêche à
/// pied and bateau, option 2). The score is multiplied by
/// `RuleSignals.nightScorePenalty` after dark and the verdict carries the
/// « lampe frontale » caution; baignade keeps its own `.night` blocker.
public struct WalkingRule: ActivityRule {
    public let activity = Activity.walking
    public let threshold = 0.6

    public static let maximumWindSpeed: Double = 30
    public static let temperatureRange = 8.0 ... 30.0

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
        if !Self.temperatureRange.contains(conditions.weather.temperature) {
            blockers.append(.temperature)
        }
        if RuleSignals.isBeyondValidityHorizon(conditions) {
            blockers.append(.dataUnavailable)
        }
        return blockers
    }

    public func score(_ conditions: Conditions) -> Double {
        let rain = RuleSignals.precipitationScore(conditions.weather)
        let wind = ScoreMath.linear(conditions.weather.wind.speed, zeroAt: 40, fullAt: 30)
        let temperature = ScoreMath.trapezoid(
            conditions.weather.temperature,
            full: 8 ... 30,
            zero: -2 ... 38)
        return ScoreMath.weighted([
            (rain, 0.40),
            (wind, 0.30),
            (temperature, 0.30)
        ]) * RuleSignals.nightScoreMultiplier(conditions)
    }
}
