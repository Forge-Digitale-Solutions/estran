import Foundation

public struct TideEvent: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable {
        case high
        case low
    }

    public let time: Date
    public let kind: Kind
    /// Height in meters.
    public let height: Double

    public init(time: Date, kind: Kind, height: Double) {
        self.time = time
        self.kind = kind
        self.height = height
    }
}

public struct TidePoint: Codable, Hashable, Sendable {
    public let time: Date
    /// Height in meters.
    public let height: Double

    public init(time: Date, height: Double) {
        self.time = time
        self.height = height
    }
}

public struct TideState: Codable, Hashable, Sendable {
    /// Where `coefficient` comes from.
    ///
    /// The national tide coefficient is defined at **Brest**
    /// (`C = (H_h − H_b) / 6.10 × 100`, clamped 20...120). The engine computes
    /// it from the station whose role is `coefficientReference`; when that
    /// station is absent or past its horizon, it falls back to a **local
    /// proxy** (`range / meanSpringRange × 100`), which is not the national
    /// value. Safety gates that depend on the national coefficient require
    /// `.nationalBrest` **and** `coefficientValidated`.
    public enum CoefficientSource: String, Codable, Hashable, Sendable {
        /// National coefficient, computed from the Brest reference station.
        case nationalBrest
        /// Local range ratio. Not the national coefficient.
        case localProxy
    }

    public let current: TideEvent?
    public let next: TideEvent?
    /// Tide coefficient, 20...120. See `coefficientSource` before using it for
    /// a safety decision.
    public let coefficient: Int
    /// Provenance of `coefficient`.
    public let coefficientSource: CoefficientSource
    /// `true` only when the national coefficient model has been validated
    /// against a published Annuaire sample.
    ///
    /// A fitted Brest model is **not** a validated coefficient: it can be off by
    /// several points (review Z23). Safety gates that depend on the national
    /// coefficient require this flag, not only `coefficientSource`, so fixing
    /// the computation cannot silently switch baignade on.
    public let coefficientValidated: Bool
    /// Samples used by the day chart.
    public let curve: [TidePoint]
    /// Samples covering the day **plus a safety margin**, used by the interval
    /// helpers. A decision within one envelope of local midnight must still see
    /// the tide on both sides of the boundary.
    public let safetyCurve: [TidePoint]
    /// Validity horizon of the station constants, copied for interval checks.
    ///
    /// The gate reads up to `at + u_t`, so the horizon must be checked there,
    /// not only at `at`. `nil` means no declared horizon (synthetic fixtures).
    public let validUntil: Date?

    public init(
        current: TideEvent?,
        next: TideEvent?,
        coefficient: Int,
        coefficientSource: CoefficientSource = .localProxy,
        coefficientValidated: Bool = false,
        curve: [TidePoint],
        safetyCurve: [TidePoint]? = nil,
        validUntil: Date? = nil)
    {
        self.current = current
        self.next = next
        self.coefficient = coefficient
        self.coefficientSource = coefficientSource
        self.coefficientValidated = coefficientValidated
        self.curve = curve
        self.safetyCurve = safetyCurve ?? curve
        self.validUntil = validUntil
    }
}

public extension TideState {
    /// Highest minus lowest predicted height over the local day, in metres.
    ///
    /// This is the **local predicted range** that drives the swimming level,
    /// not the national coefficient (review v11). `nil` when the day curve is
    /// empty or flat.
    var dailyRange: Double? {
        let heights = curve.map(\.height)
        guard let low = heights.min(), let high = heights.max(), high > low else {
            return nil
        }
        return high - low
    }

    /// `true` while the water rises (the last event was a low tide), `false` while
    /// it falls, `nil` when the state carries no last event.
    var isRising: Bool? {
        guard let current else { return nil }
        switch current.kind {
        case .low:
            return true
        case .high:
            return false
        }
    }

    /// Position between the last and the next event, from 0 to 1, or `nil` when
    /// `date` falls outside the covered interval.
    func progress(at date: Date) -> Double? {
        guard let current, let next, next.time > current.time, date >= current.time,
              date <= next.time else { return nil }
        return (date.timeIntervalSince(current.time)) / next.time.timeIntervalSince(current.time)
    }

    /// Closest event of `kind` around `date`, using the adjacent events only.
    func nearestEvent(of kind: TideEvent.Kind, to date: Date) -> TideEvent? {
        [current, next]
            .compactMap(\.self)
            .filter { $0.kind == kind }
            .min { abs($0.time.timeIntervalSince(date)) < abs($1.time.timeIntervalSince(date)) }
    }

    /// Absolute minutes between `date` and the closest event of `kind`.
    func minutesFromNearestEvent(of kind: TideEvent.Kind, to date: Date) -> Double? {
        nearestEvent(of: kind, to: date)
            .map { abs($0.time.timeIntervalSince(date)) / 60 }
    }

    /// `true` within `tolerance` seconds of a high or low water.
    func isSlack(at date: Date, tolerance: TimeInterval = 20 * 60) -> Bool {
        [current, next]
            .compactMap(\.self)
            .contains { abs($0.time.timeIntervalSince(date)) <= tolerance }
    }

    /// Interpolated height in meters at `date`, or `nil` outside the covered
    /// samples.
    ///
    /// Exact event times return the event height, so a low water between two
    /// 10-minute curve samples is not underestimated by interpolation. The
    /// lookup uses `safetyCurve`, which extends beyond the local day, so a
    /// decision near midnight is still covered.
    func height(at date: Date) -> Double? {
        if let current, date == current.time {
            return current.height
        }
        if let next, date == next.time {
            return next.height
        }
        let samples = safetyCurve.isEmpty ? curve : safetyCurve
        guard let first = samples.first, let last = samples.last,
              date >= first.time, date <= last.time
        else {
            return nil
        }
        if let exact = samples.first(where: { $0.time == date }) {
            return exact.height
        }
        guard let upperIndex = samples.firstIndex(where: { $0.time > date }), upperIndex > 0 else {
            return nil
        }
        let lower = samples[upperIndex - 1]
        let upper = samples[upperIndex]
        let span = upper.time.timeIntervalSince(lower.time)
        guard span > 0 else { return upper.height }
        let fraction = date.timeIntervalSince(lower.time) / span
        return lower.height + (upper.height - lower.height) * fraction
    }

    // MARK: - Interval safety (uncertainty envelope)

    /// `true` when `safetyCurve` covers the whole `[start, end]` interval.
    ///
    /// The interval helpers return `nil` when this fails, so the rules emit
    /// `.dataUnavailable` instead of evaluating a partial interval. Without
    /// this guard, a decision within one envelope of local midnight would
    /// silently ignore the part of the interval outside the day curve.
    func coversInterval(from start: Date, to end: Date) -> Bool {
        guard start <= end else { return false }
        let samples = safetyCurve.isEmpty ? curve : safetyCurve
        guard let first = samples.first, let last = samples.last else { return false }
        return start >= first.time && end <= last.time
    }

    /// Extrema visible in the safety samples, refined by a three-point
    /// parabolic fit. They complement the exact `current`/`next` events when a
    /// safety interval extends across an event.
    var curveEvents: [TideEvent] {
        let samples = safetyCurve.isEmpty ? curve : safetyCurve
        guard samples.count >= 3 else { return [] }
        var events: [TideEvent] = []
        for index in 1 ..< samples.count - 1 {
            let previous = samples[index - 1]
            let current = samples[index]
            let next = samples[index + 1]
            let before = current.height - previous.height
            let after = next.height - current.height
            let isMaximum = before > 0 && after < 0
            let isMinimum = before < 0 && after > 0
            guard isMaximum || isMinimum else { continue }
            let denominator = previous.height - 2 * current.height + next.height
            let offset = denominator == 0
                ? 0
                : 0.5 * (previous.height - next.height) / denominator
            let step = next.time.timeIntervalSince(current.time)
            let time = current.time.addingTimeInterval(offset * step)
            let height = current.height - 0.25 * (previous.height - next.height) * offset
            events.append(TideEvent(time: time, kind: isMaximum ? .high : .low, height: height))
        }
        return events
    }

    /// Every known extremum: the exact `current`/`next` events first, then the
    /// curve-derived extrema that are not already represented within 15 min.
    var allEvents: [TideEvent] {
        var events: [TideEvent] = []
        if let current {
            events.append(current)
        }
        if let next {
            events.append(next)
        }
        for candidate in curveEvents {
            let alreadyKnown = events.contains {
                $0.kind == candidate.kind
                    && abs($0.time.timeIntervalSince(candidate.time)) < 15 * 60
            }
            if !alreadyKnown {
                events.append(candidate)
            }
        }
        return events.sorted { $0.time < $1.time }
    }

    /// Minimum height in meters over `[start, end]`, including exact event
    /// heights, or `nil` when the interval is not fully covered.
    func minimumHeight(from start: Date, to end: Date) -> Double? {
        guard coversInterval(from: start, to: end) else { return nil }
        let samples = safetyCurve.isEmpty ? curve : safetyCurve
        var values = samples
            .filter { $0.time >= start && $0.time <= end }
            .map(\.height)
        if let height = height(at: start) {
            values.append(height)
        }
        if end != start, let height = height(at: end) {
            values.append(height)
        }
        if let current, current.time >= start, current.time <= end {
            values.append(current.height)
        }
        if let next, next.time >= start, next.time <= end {
            values.append(next.height)
        }
        return values.min()
    }

    /// Maximum height in meters over `[start, end]`, including exact event
    /// heights, or `nil` when the interval is not fully covered.
    func maximumHeight(from start: Date, to end: Date) -> Double? {
        guard coversInterval(from: start, to: end) else { return nil }
        let samples = safetyCurve.isEmpty ? curve : safetyCurve
        var values = samples
            .filter { $0.time >= start && $0.time <= end }
            .map(\.height)
        if let height = height(at: start) {
            values.append(height)
        }
        if end != start, let height = height(at: end) {
            values.append(height)
        }
        if let current, current.time >= start, current.time <= end {
            values.append(current.height)
        }
        if let next, next.time >= start, next.time <= end {
            values.append(next.height)
        }
        return values.max()
    }

    /// Largest distance, in minutes, from any instant in `[start, end]` to the
    /// nearest event of `kind`. `nil` when the interval is not covered or no
    /// event of that kind is known.
    func maximumMinutesFromNearestEvent(
        of kind: TideEvent.Kind,
        from start: Date,
        to end: Date,
        step: TimeInterval = 5 * 60) -> Double?
    {
        guard coversInterval(from: start, to: end) else { return nil }
        let candidates = allEvents.filter { $0.kind == kind }
        guard !candidates.isEmpty else { return nil }
        var times: [Date] = []
        var time = start
        while time < end {
            times.append(time)
            time = time.addingTimeInterval(step)
        }
        times.append(end)
        var maximum = 0.0
        for time in times {
            guard let nearest = candidates.min(by: {
                abs($0.time.timeIntervalSince(time)) < abs($1.time.timeIntervalSince(time))
            }) else {
                return nil
            }
            maximum = max(maximum, abs(nearest.time.timeIntervalSince(time)) / 60)
        }
        return maximum
    }

    /// Phase at `date`, from 0 at the previous extremum to 1 at the next one.
    /// `nil` when the date is not bracketed by two known events.
    func phase(at date: Date) -> Double? {
        let events = allEvents
        guard let previous = events.last(where: { $0.time <= date }),
              let next = events.first(where: { $0.time > date }),
              next.time > previous.time
        else {
            return nil
        }
        return date.timeIntervalSince(previous.time) / next.time.timeIntervalSince(previous.time)
    }

    /// Whether the phase over `[start, end]` intersects `band`.
    ///
    /// An extremum inside the interval makes the phase wrap through `0...1`,
    /// so the band is always intersected. `nil` when the phase cannot be
    /// computed at both ends.
    func phaseIntersects(_ band: ClosedRange<Double>, from start: Date, to end: Date) -> Bool? {
        guard coversInterval(from: start, to: end) else { return nil }
        if allEvents.contains(where: { $0.time > start && $0.time < end }) {
            return true
        }
        guard let startPhase = phase(at: start),
              let endPhase = phase(at: end)
        else {
            return nil
        }
        let lower = min(startPhase, endPhase)
        let upper = max(startPhase, endPhase)
        return lower <= band.upperBound && upper >= band.lowerBound
    }
}
