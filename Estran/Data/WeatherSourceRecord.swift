import EstranCore
import Foundation

/// Which provider answered the air weather for a spot.
///
/// **Why the decision is written down.** WeatherKit's terms require the Apple
/// Weather mark and a link to its legal page wherever its data is displayed,
/// and Open-Meteo asks for a CC BY 4.0 credit in return. A fallback that stays
/// invisible would either drop a required credit or credit the wrong party, so
/// `FallbackWeatherSource` records the branch it took at the moment it takes
/// it, and every surface that shows a weather value reads that record.
///
/// This file is compiled by both the app and the widget extension (see
/// `project.yml`): the extension has no provider of its own, it renders the
/// snapshot the app wrote and must attribute it the same way.
///
/// Public because `WeatherKitService` is a public actor whose `kind` names it.
public enum WeatherSourceKind: String, Codable, Hashable, Sendable {
    /// Apple WeatherKit answered.
    case appleWeather
    /// WeatherKit could not answer; Open-Meteo supplied the values.
    case openMeteo

    /// The French name shown after « Météo : ».
    public var displayName: String {
        switch self {
        case .appleWeather: "Apple Météo"
        case .openMeteo: "Open-Meteo"
        }
    }

    /// The licence line drawn under the name. Apple's credit carries the mark
    /// and the legal page instead of a licence name.
    public var licenceLine: String? {
        switch self {
        case .appleWeather: nil
        case .openMeteo: "CC BY 4.0"
        }
    }
}

/// Per-spot record of the weather source, in the App Group next to the widget
/// snapshot, so the extension can attribute what it draws.
///
/// A missing file is an unknown source, never a default: the widgets then show
/// no credit rather than the wrong one. The app keeps its own in-memory copy
/// (`WeatherAttributionStore`), so a nil container (unit tests, Linux) only
/// costs the widget's credit, not the app's.
enum WeatherSourceRecord {
    static let fileName = "weather-sources.json"

    static func save(
        _ kind: WeatherSourceKind,
        forSpotID spotID: String,
        in containerURL: URL? = WidgetSnapshot.containerURL())
    {
        guard let containerURL else { return }
        var bySpot = loadAll(in: containerURL) ?? [:]
        bySpot[spotID] = kind
        guard let data = try? JSONEncoder().encode(bySpot) else { return }
        try? FileManager.default.createDirectory(
            at: containerURL,
            withIntermediateDirectories: true)
        try? data.write(
            to: containerURL.appendingPathComponent(fileName),
            options: .atomic)
    }

    /// Removes the spot's entry: sample data has no external source to credit,
    /// and a stale credit would survive into the widget.
    static func remove(
        forSpotID spotID: String,
        in containerURL: URL? = WidgetSnapshot.containerURL())
    {
        guard let containerURL, var bySpot = loadAll(in: containerURL) else { return }
        if bySpot.removeValue(forKey: spotID) != nil,
           let data = try? JSONEncoder().encode(bySpot)
        {
            try? data.write(
                to: containerURL.appendingPathComponent(fileName),
                options: .atomic)
        }
    }

    static func load(
        forSpotID spotID: String,
        from containerURL: URL? = WidgetSnapshot.containerURL()) -> WeatherSourceKind?
    {
        guard let containerURL else { return nil }
        return loadAll(in: containerURL)?[spotID]
    }

    private static func loadAll(in containerURL: URL) -> [String: WeatherSourceKind]? {
        let url = containerURL.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([String: WeatherSourceKind].self, from: data)
    }
}
