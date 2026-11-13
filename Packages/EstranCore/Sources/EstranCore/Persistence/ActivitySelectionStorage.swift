import Foundation

/// Shared storage for the single activity selection, the sibling of
/// `SpotSelectionStorage`.
///
/// Exactly **one** activity is selected in the product (`DESIGN_REFERENCE.md`
/// §6.1): picking one on Home, in the picker, from a widget tap or from an App
/// Intent all land here. Keeping the value in the App Group means the app opens
/// on the user's activity after a relaunch instead of falling back to the
/// default, and a widget set to « Automatique » follows the same value.
///
/// The type never validates the identifier beyond `Activity(rawValue:)`: a
/// value written by another build (an activity since removed from
/// `Activity.allCases`) resolves to `fallback` rather than to whatever came
/// first, and a missing value is the first-launch case, not an error.
public struct ActivitySelectionStorage: @unchecked Sendable {
    /// Key inside the App Group defaults, next to `selectedSpotID`.
    public static let key = "selectedActivityID"

    /// What a missing or unknown stored value resolves to.
    ///
    /// The app's historical default, a real activity, never an empty state: a
    /// first launch still answers something before the picker appears.
    public static let fallback: Activity = .shoreFishing

    private let defaults: UserDefaults?

    /// Production storage, backed by the shared App Group.
    public init(suiteName: String = EstranAppGroup.identifier) {
        defaults = UserDefaults(suiteName: suiteName)
    }

    /// Injectable storage for tests and previews.
    public init(defaults: UserDefaults?) {
        self.defaults = defaults
    }

    /// The stored activity, or `fallback` when nothing usable was stored.
    ///
    /// Never returns `nil`: every caller needs an activity to render, and the
    /// absence of a stored choice is not a state the UI has a surface for.
    public func load() -> Activity {
        guard let raw = defaults?.string(forKey: Self.key) else {
            return Self.fallback
        }
        return Activity(rawValue: raw) ?? Self.fallback
    }

    /// Persists the selection.
    public func save(_ activity: Activity) {
        defaults?.set(activity.rawValue, forKey: Self.key)
    }

    /// Removes the selection, so the next launch falls back to the default.
    public func clear() {
        defaults?.removeObject(forKey: Self.key)
    }
}
