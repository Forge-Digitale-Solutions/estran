import Foundation

/// Shared storage for the single spot selection used across the app, the
/// widgets, the Live Activity and the App Intents.
///
/// There is exactly **one** selection in the product (`DESIGN_REFERENCE.md`
/// §6.1). Keeping the value in the App Group means the widget and Siri read the
/// same spot as the map, without a backend and without a second source of
/// truth.
///
/// The type is a thin, testable wrapper: it never validates the identifier, so
/// a stale value cannot silently remove a spot from the catalog. Callers
/// resolve it through `SpotCatalog.spot(id:)`, which falls back to the default.
public struct SpotSelectionStorage: @unchecked Sendable {
    /// Key inside the App Group defaults.
    public static let key = "selectedSpotID"

    private let defaults: UserDefaults?

    /// Production storage, backed by the shared App Group.
    public init(suiteName: String = EstranAppGroup.identifier) {
        defaults = UserDefaults(suiteName: suiteName)
    }

    /// Injectable storage for tests and previews.
    public init(defaults: UserDefaults?) {
        self.defaults = defaults
    }

    /// Stored identifier, or `nil` when the user has never chosen a spot.
    public func load() -> String? {
        defaults?.string(forKey: Self.key)
    }

    /// Persists the selection. Empty identifiers are ignored.
    public func save(_ spotID: String) {
        guard !spotID.isEmpty else { return }
        defaults?.set(spotID, forKey: Self.key)
    }

    /// Removes the selection, so the next launch falls back to the default.
    public func clear() {
        defaults?.removeObject(forKey: Self.key)
    }
}
