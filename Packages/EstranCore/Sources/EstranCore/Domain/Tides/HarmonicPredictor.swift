import Foundation

/// Pure harmonic tide predictor: `h(t) = Z0 + Σ H_i · cos(ω_i · t − g_i)`.
///
/// `t` is UTC time in hours since the model epoch `2000-01-01T00:00:00Z`,
/// `Z0` the station mean sea level, `H_i` the constituent amplitudes and
/// `g_i` the phase lags. No nodal correction, no equilibrium argument beyond
/// the linear term: this is the documented baseline of the project.
///
/// Callers must pass a station whose `TidalStation.validationError` is `nil`.
/// `TideEngine` enforces this at its boundary; calling the predictor directly
/// with unvalidated data is a programming error and may yield non-finite
/// heights.
public struct HarmonicPredictor: Sendable {
    public init() {}

    /// Model reference epoch (`2000-01-01T00:00:00Z`) used as `t = 0`.
    static let epoch = Date(timeIntervalSince1970: 946_684_800)

    /// Grid step, in seconds, used to bracket extrema before refinement.
    static let extremaScanStep: TimeInterval = 300

    /// Ternary-search iterations when refining an extremum.
    static let extremaRefinementIterations = 90

    /// UTC time in hours since the model epoch.
    func hoursSinceEpoch(_ date: Date) -> Double {
        date.timeIntervalSince(Self.epoch) / 3600
    }

    /// Height in meters at a given model time (hours since epoch).
    func height(for station: TidalStation, atHours hours: Double) -> Double {
        var height = station.meanSeaLevel
        for constituent in station.constituents {
            guard let degreesPerHour = constituent.speedDegreesPerHour else { continue }
            let omega = degreesPerHour * .pi / 180
            let phase = constituent.phaseDegrees * .pi / 180
            height += constituent.amplitude * cos(omega * hours - phase)
        }
        return height
    }

    /// Height in meters at `date`.
    public func height(for station: TidalStation, at date: Date) -> Double {
        height(for: station, atHours: hoursSinceEpoch(date))
    }

    /// Slope of the height curve, in meters per hour, at model time `hours`.
    func slope(for station: TidalStation, atHours hours: Double) -> Double {
        var slope = 0.0
        for constituent in station.constituents {
            guard let degreesPerHour = constituent.speedDegreesPerHour else { continue }
            let omega = degreesPerHour * .pi / 180
            let phase = constituent.phaseDegrees * .pi / 180
            slope -= constituent.amplitude * omega * sin(omega * hours - phase)
        }
        return slope
    }

    /// All local extrema between `start` and `end`, sorted by time.
    ///
    /// A 5-minute grid brackets each sign change of the first difference; a
    /// bounded ternary search then refines the extremum to sub-second
    /// precision, and the height is re-evaluated at the refined time.
    public func extrema(for station: TidalStation, from start: Date, to end: Date) -> [TideEvent] {
        guard start < end else { return [] }

        var samples: [(time: Date, height: Double)] = []
        var time = start
        while time < end {
            samples.append((time, height(for: station, at: time)))
            time = time.addingTimeInterval(Self.extremaScanStep)
        }
        if samples.last?.time != end {
            samples.append((end, height(for: station, at: end)))
        }
        guard samples.count >= 3 else { return [] }

        var events: [TideEvent] = []
        for index in 1 ..< samples.count - 1 {
            let before = samples[index].height - samples[index - 1].height
            let after = samples[index + 1].height - samples[index].height
            if before > 0, after < 0 {
                events.append(event(
                    for: station,
                    between: samples[index - 1].time,
                    and: samples[index + 1].time,
                    maximum: true))
            } else if before < 0, after > 0 {
                events.append(event(
                    for: station,
                    between: samples[index - 1].time,
                    and: samples[index + 1].time,
                    maximum: false))
            }
        }
        return events
    }

    /// Refines one extremum bracketed by `start` and `end` with a bounded
    /// ternary search on the height curve.
    private func event(
        for station: TidalStation,
        between start: Date,
        and end: Date,
        maximum: Bool) -> TideEvent
    {
        var lower = start
        var upper = end
        for _ in 0 ..< Self.extremaRefinementIterations {
            let third = upper.timeIntervalSince(lower) / 3
            let first = lower.addingTimeInterval(third)
            let second = upper.addingTimeInterval(-third)
            let firstHeight = height(for: station, at: first)
            let secondHeight = height(for: station, at: second)
            let moveLower = maximum ? firstHeight < secondHeight : firstHeight > secondHeight
            if moveLower {
                lower = first
            } else {
                upper = second
            }
        }
        let time = lower.addingTimeInterval(upper.timeIntervalSince(lower) / 2)
        return TideEvent(time: time, kind: maximum ? .high : .low, height: height(for: station, at: time))
    }

    /// French tide coefficient for the local day containing `date`,
    /// computed from `station.timezone` and clamped to `20...120`.
    ///
    /// This is the **local proxy** (`range / meanSpringRange × 100`), not the
    /// national coefficient. At Brest the fitted mean spring range is 5.4807,
    /// while the national formula divides by 6.10: using this method there would
    /// read +11 % high. Use `nationalCoefficient(for:on:)` for the national
    /// value (review Z23).
    public func coefficient(for station: TidalStation, on date: Date) -> Int {
        guard station.meanSpringRange > 0 else { return 20 }
        let range = dayRange(for: station, on: date)
        let raw = range / station.meanSpringRange * 100
        guard raw.isFinite else { return 20 }
        return min(120, max(20, Int(raw.rounded())))
    }

    /// National French tide coefficient, defined at Brest as
    /// `C = (H_h − H_b) / 6.10 × 100`, clamped to `20...120`.
    ///
    /// The divisor is the conventional 6.10, **not** the fitted
    /// `meanSpringRange` (review Z23). `station` must be the reference station
    /// whose role is `coefficientReference`.
    public func nationalCoefficient(for station: TidalStation, on date: Date) -> Int {
        let range = dayRange(for: station, on: date)
        let raw = range / Self.nationalCoefficientDivisor * 100
        guard raw.isFinite else { return 20 }
        return min(120, max(20, Int(raw.rounded())))
    }

    /// Conventional national coefficient divisor (metres).
    public static let nationalCoefficientDivisor: Double = 6.10

    /// Highest-minus-lowest height over the local day, in metres.
    private func dayRange(for station: TidalStation, on date: Date) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = station.timezone
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return 0
        }
        let events = extrema(for: station, from: dayStart, to: dayEnd)
        if events.count >= 2 {
            let heights = events.map(\.height)
            return (heights.max() ?? 0) - (heights.min() ?? 0)
        }
        return sampledRange(for: station, from: dayStart, to: dayEnd)
    }

    /// Highest-minus-lowest height over the range, sampled on a 5-minute grid.
    private func sampledRange(for station: TidalStation, from start: Date, to end: Date) -> Double {
        var lowest = Double.infinity
        var highest = -Double.infinity
        var time = start
        while time < end {
            let height = height(for: station, at: time)
            lowest = min(lowest, height)
            highest = max(highest, height)
            time = time.addingTimeInterval(Self.extremaScanStep)
        }
        let finalHeight = height(for: station, at: end)
        lowest = min(lowest, finalHeight)
        highest = max(highest, finalHeight)
        return highest - lowest
    }
}
