import Foundation

/// Small pure helpers shared by the activity rules.
///
/// Every function returns a value in `0...1` and is deterministic, so a rule
/// score can be reproduced from its inputs alone.
public enum ScoreMath {
    /// Clamps `value` to `0...1`.
    public static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    /// Linear ramp: `0` at `zeroAt`, `1` at `fullAt`, clamped outside.
    ///
    /// `zeroAt` may be greater than `fullAt` for signals where a smaller value
    /// is better (wind speed, precipitation chance, swell height).
    public static func linear(_ value: Double, zeroAt: Double, fullAt: Double) -> Double {
        guard zeroAt != fullAt else {
            return value >= fullAt ? 1 : 0
        }
        return clamp((value - zeroAt) / (fullAt - zeroAt))
    }

    /// `1` inside `full`, `0` outside `zero`, linear in the transition bands.
    ///
    /// `zero.lowerBound` must be lower than `full.lowerBound` and
    /// `zero.upperBound` higher than `full.upperBound`.
    public static func trapezoid(_ value: Double, full: ClosedRange<Double>, zero: ClosedRange<Double>) -> Double {
        if value < zero.lowerBound || value > zero.upperBound {
            return 0
        }
        if value < full.lowerBound {
            return linear(value, zeroAt: zero.lowerBound, fullAt: full.lowerBound)
        }
        if value > full.upperBound {
            return linear(value, zeroAt: zero.upperBound, fullAt: full.upperBound)
        }
        return 1
    }

    /// Weighted mean of `(score, weight)` pairs, clamped to `0...1`.
    public static func weighted(_ components: [(score: Double, weight: Double)]) -> Double {
        let totalWeight = components.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return 0 }
        let total = components.reduce(0) { $0 + clamp($1.score) * $1.weight }
        return clamp(total / totalWeight)
    }

    /// Smallest angle in degrees between two bearings, in `0...180`.
    public static func angularDistance(_ first: Double, _ second: Double) -> Double {
        let difference = abs((first - second).truncatingRemainder(dividingBy: 360))
        return difference > 180 ? 360 - difference : difference
    }

    /// Wind component along the seaward axis.
    ///
    /// `windDirection` is the direction the wind comes **from**, in degrees.
    /// `coastOrientation` is the direction the shore faces (seaward normal).
    /// Returns `1` for a fully onshore wind, `-1` for a fully offshore wind and
    /// `0` for a cross-shore wind.
    public static func onshoreComponent(windDirection: Double, coastOrientation: Double) -> Double {
        cos(angularDistance(windDirection, coastOrientation) * .pi / 180)
    }
}
