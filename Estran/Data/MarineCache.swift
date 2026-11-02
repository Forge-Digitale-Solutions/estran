import EstranCore
import Foundation

/// 30-minute cache for the marine samples, one JSON file per spot.
///
/// It exists so a spot switch, a tab change or a relaunch does not hit the
/// network again, and so the app can still answer when the network is down: a
/// **stale** sample is returned only when it is younger than `staleAfter`, and
/// the caller decides what to do with it. Nothing is ever invented to fill a
/// hole.
actor MarineCache {
    /// Fresh window: no network call.
    static let freshInterval: TimeInterval = 30 * 60
    /// Oldest data still usable offline: two hours. Past that the app says the
    /// marine data is unavailable rather than showing a stale sea.
    static let staleInterval: TimeInterval = 2 * 60 * 60

    private struct Entry: Codable {
        let storedAt: Date
        let samples: [MarineSample]
    }

    private let directory: URL
    private let calendar = Calendar(identifier: .gregorian)

    /// - Parameter directory: defaults to the App Group container, so the widget
    ///   and the app read the same cache. Falls back to `Caches` when the group
    ///   is unavailable (unit tests, previews).
    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            self.directory = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: EstranAppGroup.identifier)?
                .appendingPathComponent("MarineCache", isDirectory: true)
                ?? FileManager.default.temporaryDirectory
                .appendingPathComponent("EstranMarineCache", isDirectory: true)
        }
    }

    /// Cached samples when they are still usable at `now`, otherwise `nil`.
    func samples(for spotID: String, now: Date = Date()) -> [MarineSample]? {
        guard let entry = read(spotID: spotID) else { return nil }
        let age = now.timeIntervalSince(entry.storedAt)
        guard age >= 0, age <= Self.staleInterval, !entry.samples.isEmpty else { return nil }
        return entry.samples
    }

    /// `true` when the cached entry is fresh enough to skip the network.
    func isFresh(for spotID: String, now: Date = Date()) -> Bool {
        guard let entry = read(spotID: spotID) else { return false }
        let age = now.timeIntervalSince(entry.storedAt)
        return age >= 0 && age <= Self.freshInterval && !entry.samples.isEmpty
    }

    func store(_ samples: [MarineSample], for spotID: String, now: Date = Date()) {
        guard !samples.isEmpty else { return }
        let entry = Entry(storedAt: now, samples: samples)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entry) else { return }
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true)
        try? data.write(to: url(for: spotID), options: .atomic)
    }

    func clear() {
        try? FileManager.default.removeItem(at: directory)
    }

    private func read(spotID: String) -> Entry? {
        guard let data = try? Data(contentsOf: url(for: spotID)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Entry.self, from: data)
    }

    private func url(for spotID: String) -> URL {
        directory.appendingPathComponent("\(spotID).json")
    }
}
