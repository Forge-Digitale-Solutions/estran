import Foundation

/// The URL a widget tap opens, and how the app parses it.
///
/// Widgets are configured per spot and per activity; tapping one opens Estran
/// on exactly that combination. The scheme is private to Estran and tiny, so
/// the parser only accepts what this type emits — a stray URL never reaches a
/// default spot silently.
public enum WidgetDeepLink {
    public static let scheme = "estran"

    private static let host = "open"
    private static let spotKey = "spot"
    private static let activityKey = "activity"

    /// The value carried by a widget tap: a concrete spot and activity.
    public struct Target: Equatable, Sendable {
        public let spotID: String
        public let activity: Activity

        public init(spotID: String, activity: Activity) {
            self.spotID = spotID
            self.activity = activity
        }
    }

    public static func url(spotID: String, activity: Activity) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [
            URLQueryItem(name: spotKey, value: spotID),
            URLQueryItem(name: activityKey, value: activity.rawValue)
        ]
        return components.url ?? URL(fileURLWithPath: "/")
    }

    /// Parses a widget URL into its target, or `nil` when the URL is not one
    /// Estran emitted (unknown scheme, missing or unknown spot/activity).
    public static func parse(_ url: URL) -> Target? {
        guard url.scheme == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host == host,
              let items = components.queryItems,
              let spotID = items.first(where: { $0.name == spotKey })?.value,
              !spotID.isEmpty,
              SpotCatalog.spot(id: spotID) != nil,
              let rawActivity = items.first(where: { $0.name == activityKey })?.value,
              let activity = Activity(rawValue: rawActivity)
        else {
            return nil
        }
        return Target(spotID: spotID, activity: activity)
    }
}
