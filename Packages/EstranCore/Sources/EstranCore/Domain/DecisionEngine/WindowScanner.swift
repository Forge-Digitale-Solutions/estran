import Foundation

/// Scans a forecast for contiguous good windows.
///
/// A window is a run of samples for which `isGood` is true, at a regular
/// sampling step. It must last at least `minimumDuration` and start at or after
/// `now` (a run already in progress is clamped to `now`). A sample that fails
/// `isGood` breaks the run, so a blocked sample can never sit inside a window.
public enum WindowScanner {
    /// Nominal forecast step, matching the 30-minute decision horizon.
    public static let defaultStep: TimeInterval = 30 * 60
    /// Minimum length of a usable window.
    public static let minimumDuration: TimeInterval = 60 * 60

    /// Earliest good window after `now`, or `nil`.
    ///
    /// `step` is inferred from the series when omitted, so a 30-minute series
    /// and an hourly series are both handled correctly.
    public static func firstWindow(
        in forecast: [Conditions],
        after now: Date,
        step: TimeInterval? = nil,
        minimumDuration: TimeInterval = minimumDuration,
        isGood: (Conditions) -> Bool) -> DateInterval?
    {
        allWindows(
            in: forecast,
            after: now,
            step: step,
            minimumDuration: minimumDuration,
            isGood: isGood).first
    }

    /// Every good window after `now`, sorted by start date.
    public static func allWindows(
        in forecast: [Conditions],
        after now: Date,
        step: TimeInterval? = nil,
        minimumDuration: TimeInterval = minimumDuration,
        isGood: (Conditions) -> Bool) -> [DateInterval]
    {
        let samples = forecast.sorted { $0.at < $1.at }
        guard !samples.isEmpty else { return [] }
        let resolvedStep = step ?? inferredStep(samples) ?? defaultStep
        guard resolvedStep > 0 else { return [] }

        var windows: [DateInterval] = []
        var runStart: Date?
        var runEnd: Date?

        func flush() {
            defer {
                runStart = nil
                runEnd = nil
            }
            guard let start = runStart, let end = runEnd else { return }
            let clampedStart = max(start, now)
            let clampedEnd = max(end, now)
            guard clampedEnd.timeIntervalSince(clampedStart) >= minimumDuration else { return }
            windows.append(DateInterval(start: clampedStart, end: clampedEnd))
        }

        for sample in samples {
            if isGood(sample) {
                if let end = runEnd, sample.at.timeIntervalSince(end) <= resolvedStep * 1.5 {
                    runEnd = sample.at.addingTimeInterval(resolvedStep)
                } else {
                    flush()
                    runStart = sample.at
                    runEnd = sample.at.addingTimeInterval(resolvedStep)
                }
            } else {
                flush()
            }
        }
        flush()
        return windows
    }

    /// Median positive spacing between consecutive samples, if any.
    private static func inferredStep(_ samples: [Conditions]) -> TimeInterval? {
        let gaps = zip(samples, samples.dropFirst())
            .map { $1.at.timeIntervalSince($0.at) }
            .filter { $0 > 0 }
            .sorted()
        guard !gaps.isEmpty else { return nil }
        return gaps[gaps.count / 2]
    }
}
