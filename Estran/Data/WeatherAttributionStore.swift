import EstranCore
import Foundation
import Observation
import OSLog

#if canImport(WeatherKit)
    import WeatherKit
#endif

/// Apple Weather's attribution, as the API returns it.
///
/// The app is dark-only, so `markURL` is the **combined dark mark** (Apple logo
/// plus the localized « Météo » wordmark) served by WeatherKit; the light mark
/// is deliberately not carried around, because no surface would use it.
struct AppleWeatherAttribution: Equatable, Sendable {
    let serviceName: String
    let markURL: URL
    let legalPageURL: URL
}

/// The weather source of what is on screen, and the Apple mark that goes with
/// it.
///
/// **Two responsibilities, one place.** `FallbackWeatherSource` records which
/// provider answered (`record(_:forSpotID:)`), and this store turns that into
/// the attribution the UI shows: the Apple mark and « Sources légales » when
/// WeatherKit answered, « Météo : Open-Meteo · CC BY 4.0 » when the fallback
/// did, nothing when the values are sample data.
///
/// **Never a broken image.** The mark is fetched once as PNG bytes; if either
/// the attribution call or the download fails, `markImageData` stays `nil` and
/// the views fall back to the text « Météo : Apple Météo », keeping the legal
/// link whenever the attribution itself succeeded. The load is attempted once
/// per process, so an offline launch does not hammer the endpoint.
@MainActor
@Observable
final class WeatherAttributionStore {
    /// Process-wide store: the provider writes it, every surface reads it. The
    /// app has one weather source chain, so one record cannot be ambiguous.
    static let shared = WeatherAttributionStore()

    /// State of the Apple mark, kept as a value so the views (and the tests)
    /// can distinguish « pas encore chargé », « chargé » and « indisponible ».
    enum Mark: Equatable {
        case idle
        case loading
        case loaded(AppleWeatherAttribution)
        case unavailable
    }

    private static let logger = Logger(
        subsystem: "com.forgedigitalesolutions.estran",
        category: "weather")

    /// Source per spot id. A dictionary, not one value: the app also refreshes
    /// the *other* spot for its widget, and that call must not relabel the spot
    /// on screen.
    private(set) var sources: [String: WeatherSourceKind] = [:]
    private(set) var mark: Mark = .idle
    /// PNG bytes of the combined dark mark, once downloaded.
    private(set) var markImageData: Data?

    /// `true` once the attribution call was attempted in this process.
    @ObservationIgnored private var hasAttemptedMark = false

    private let attributionLoader: @Sendable () async throws -> AppleWeatherAttribution
    private let markDownloader: @Sendable (URL) async throws -> Data
    /// Where the per-spot record is persisted for the widget extension. `nil` in
    /// a unit test keeps the record in memory only.
    @ObservationIgnored private let recordContainer: URL?

    init(
        attributionLoader: @escaping @Sendable () async throws -> AppleWeatherAttribution =
            WeatherAttributionStore.appleAttribution,
        markDownloader: @escaping @Sendable (URL) async throws -> Data =
            WeatherAttributionStore.download,
        recordContainer: URL? = WidgetSnapshot.containerURL())
    {
        self.attributionLoader = attributionLoader
        self.markDownloader = markDownloader
        self.recordContainer = recordContainer
    }

    // MARK: - Source

    /// The source that produced `spotID`'s weather, or `nil` when nothing
    /// external answered (sample data, or no load yet).
    func source(forSpotID spotID: String) -> WeatherSourceKind? {
        sources[spotID]
    }

    /// Records the branch `FallbackWeatherSource` just took. `nil` means no
    /// external provider answered (the DEBUG sample data), so any previous
    /// credit for that spot is dropped everywhere, widget included.
    func record(_ kind: WeatherSourceKind?, forSpotID spotID: String) {
        sources[spotID] = kind
        if let kind {
            WeatherSourceRecord.save(kind, forSpotID: spotID, in: recordContainer)
        } else {
            WeatherSourceRecord.remove(forSpotID: spotID, in: recordContainer)
        }
    }

    // MARK: - Apple mark

    /// Loads the attribution and its mark, at most once per process.
    ///
    /// Called from the surfaces that would show the mark, so a launch that
    /// never displays Apple data never calls WeatherKit's attribution endpoint.
    func loadAppleAttributionIfNeeded() async {
        guard !hasAttemptedMark else { return }
        hasAttemptedMark = true
        mark = .loading

        let attribution: AppleWeatherAttribution
        do {
            attribution = try await attributionLoader()
        } catch {
            Self.logger.notice(
                "WeatherKit attribution unavailable: \(String(describing: error), privacy: .public)")
            mark = .unavailable
            return
        }
        mark = .loaded(attribution)

        do {
            markImageData = try await markDownloader(attribution.markURL)
        } catch {
            // The credit still shows as text with its legal link: a missing
            // image must never leave a broken picture on the card.
            Self.logger.notice(
                "WeatherKit mark download failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// The legal page of the loaded attribution, or `nil` before (or without)
    /// a successful call.
    var legalPageURL: URL? {
        if case let .loaded(attribution) = mark {
            return attribution.legalPageURL
        }
        return nil
    }

    // MARK: - Production loaders

    /// `WeatherService.shared.attribution`: the supported WeatherKit API for
    /// the mark and the legal page (`combinedMarkDarkURL`, `legalPageURL`).
    static func appleAttribution() async throws -> AppleWeatherAttribution {
        #if canImport(WeatherKit)
            let attribution = try await WeatherService.shared.attribution
            return AppleWeatherAttribution(
                serviceName: attribution.serviceName,
                markURL: attribution.combinedMarkDarkURL,
                legalPageURL: attribution.legalPageURL)
        #else
            throw WeatherAttributionError.unavailable
        #endif
    }

    /// The mark is a small PNG served by Apple; load it once, not per view.
    static func download(_ url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200 ..< 300).contains(http.statusCode),
              !data.isEmpty
        else {
            throw WeatherAttributionError.unavailable
        }
        return data
    }
}

enum WeatherAttributionError: Error, Equatable {
    case unavailable
}
