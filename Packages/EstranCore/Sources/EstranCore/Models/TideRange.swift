import Foundation

/// Size of the day's tide, from the **local predicted range** of the shipped
/// model — never from the national Brest coefficient.
///
/// The coefficient is computed, unvalidated and never shown (`AGENTS.md`
/// invariant 6). What a shore user actually needs is the day's marnage at *this*
/// spot: whether the water will drop far enough to uncover the bank, or whether
/// the tide is a weak neap that never really leaves the beach.
public enum TideRangeCategory: String, Codable, CaseIterable, Hashable, Sendable {
    /// The largest third of the local daily ranges.
    case spring
    /// The middle third.
    case mean
    /// The smallest third.
    case neap

    /// French label, lowercase so it reads after a value.
    public var label: String {
        switch self {
        case .spring: "grande marée"
        case .mean: "marée moyenne"
        case .neap: "petite marée"
        }
    }
}

/// Tercile thresholds of the local daily range, per station.
///
/// The bounds come from **the model itself**, over its own horizon, so they are
/// derived per spot instead of being one national table. They are terciles, not
/// safety bounds: nothing here gates a decision, and the swimming level keeps
/// its own calibrated `SwimmingRange`.
public struct TideRangeThresholds: Codable, Hashable, Sendable {
    /// A tercile needs a real sample: a fortnight is one spring/neap cycle, and
    /// fewer days would let a single festival tide define a category.
    public static let minimumSamples = 14

    /// Below this range the day is a `neap` tide.
    public let neapBelow: Double
    /// At or above this range the day is a `spring` tide.
    public let springAt: Double
    /// How many daily ranges the thresholds were derived from.
    public let sampleCount: Int

    public init(neapBelow: Double, springAt: Double, sampleCount: Int) {
        self.neapBelow = neapBelow
        self.springAt = springAt
        self.sampleCount = sampleCount
    }

    /// Smallest spread a tercile split needs to mean anything. A flat record
    /// (a single-constituent fixture, a broken model) differs only by floating
    /// noise between its two terciles, and one rogue day must not define a
    /// category: 1 cm is below any real spring/neap separation.
    public static let minimumSpread = 0.01

    /// Terciles of `dailyRanges`, or `nil` when there is not enough model output
    /// to derive them — in which case the UI shows no category at all rather
    /// than a guessed one (invariant 3).
    public init?(dailyRanges: [Double]) {
        let values = dailyRanges.filter { $0.isFinite && $0 > 0 }.sorted()
        guard values.count >= Self.minimumSamples else { return nil }
        let neapBelow = Self.quantile(values, 1.0 / 3.0)
        let springAt = Self.quantile(values, 2.0 / 3.0)
        guard springAt > neapBelow + Self.minimumSpread else { return nil }
        self.init(neapBelow: neapBelow, springAt: springAt, sampleCount: values.count)
    }

    public func category(for range: Double) -> TideRangeCategory {
        if range >= springAt {
            return .spring
        }
        if range < neapBelow {
            return .neap
        }
        return .mean
    }

    /// Linear-interpolated quantile of an ascending, non-empty sample.
    static func quantile(_ values: [Double], _ fraction: Double) -> Double {
        guard let first = values.first, let last = values.last else { return 0 }
        guard values.count > 1 else { return first }
        let position = fraction * Double(values.count - 1)
        let lowerIndex = Int(position.rounded(.down))
        let upperIndex = min(lowerIndex + 1, values.count - 1)
        guard lowerIndex < values.count else { return last }
        let lower = values[lowerIndex]
        let upper = values[upperIndex]
        return lower + (upper - lower) * (position - Double(lowerIndex))
    }
}

/// One day's marnage and its category.
public struct TideRangeDay: Hashable, Sendable {
    /// High minus adjacent low, in metres, from the shipped model.
    public let range: Double
    public let category: TideRangeCategory

    public init(range: Double, category: TideRangeCategory) {
        self.range = range
        self.category = category
    }
}

/// Derives the daily marnage and its terciles from the shipped tide model.
///
/// Everything here is pure and synchronous: the caller passes the station and a
/// reference date, and the model horizon is the only clock. No network, no
/// ambient `Date()` read, so the app and its tests agree.
public enum TideRangeBaseline {
    /// Longest horizon sampled, in days. One year covers a full nodal cycle of
    /// spring/neap modulation without walking the whole validity decade.
    public static let maximumHorizonDays = 366

    /// High minus low per local day over `days` from `date`, or the part of it
    /// the station still declares valid.
    ///
    /// A day without both a high and a low (the first or last partial day, or a
    /// day past the horizon) is skipped, never filled with a neighbour's value.
    public static func dailyRanges(
        station: TidalStation,
        from date: Date,
        days: Int = maximumHorizonDays) -> [Double]
    {
        guard days > 0 else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = station.timezone
        let predictor = HarmonicPredictor()
        let dayStart = calendar.startOfDay(for: date)
        var ranges: [Double] = []
        ranges.reserveCapacity(days)
        for offset in 0 ..< min(days, maximumHorizonDays) {
            guard let start = calendar.date(byAdding: .day, value: offset, to: dayStart),
                  let end = calendar.date(byAdding: .day, value: 1, to: start),
                  station.isValid(at: start)
            else {
                continue
            }
            let events = predictor.extrema(for: station, from: start, to: end)
            let highs = events.filter { $0.kind == .high }.map(\.height)
            let lows = events.filter { $0.kind == .low }.map(\.height)
            guard let high = highs.max(), let low = lows.min(), high > low else { continue }
            ranges.append(high - low)
        }
        return ranges
    }

    /// Terciles of the daily ranges over the model horizon from `date`.
    public static func thresholds(
        station: TidalStation,
        from date: Date,
        days: Int = maximumHorizonDays) -> TideRangeThresholds?
    {
        TideRangeThresholds(dailyRanges: dailyRanges(station: station, from: date, days: days))
    }

    /// The marnage of `date`'s local day in `timeZone`, from the extrema the
    /// engine already carries.
    ///
    /// Uses the same quantities as `dailyRanges` (the day's highest high minus
    /// its lowest low), so a day compared against the terciles is measured the
    /// way the terciles were. `nil` when the day holds only one kind of
    /// extremum: no category rather than a half-range.
    public static func range(
        of tide: TideState,
        in timeZone: TimeZone,
        at date: Date) -> Double?
    {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }
        let events = tide.allEvents.filter { $0.time >= dayStart && $0.time < dayEnd }
        let highs = events.filter { $0.kind == .high }.map(\.height)
        let lows = events.filter { $0.kind == .low }.map(\.height)
        guard let high = highs.max(), let low = lows.min(), high > low else { return nil }
        return high - low
    }

    /// The day's marnage dressed with its category, or `nil` when either the
    /// range or the thresholds are missing.
    public static func day(
        of tide: TideState,
        in timeZone: TimeZone,
        at date: Date,
        thresholds: TideRangeThresholds) -> TideRangeDay?
    {
        guard let range = range(of: tide, in: timeZone, at: date) else { return nil }
        return TideRangeDay(range: range, category: thresholds.category(for: range))
    }
}
