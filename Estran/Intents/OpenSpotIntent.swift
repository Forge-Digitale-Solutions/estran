import AppIntents
import EstranCore
import Foundation

/// Opens Estran on a spot chosen from Spotlight or Shortcuts.
///
/// Conforms to `OpenIntent` + `TargetContentProvidingIntent` so a Spotlight
/// hit on « Pointe de Grave » launches the app with that entity as the target.
/// The spot id is written to the App Group selection store so a cold launch
/// picks it up; a warm `AppModel` still needs an app-side reload hook to apply
/// the change without relaunching.
struct OpenSpotIntent: OpenIntent, TargetContentProvidingIntent {
    static var title: LocalizedStringResource {
        "Ouvrir le spot"
    }

    static var description: IntentDescription {
        IntentDescription("Ouvre Estran sur un lieu du Bassin ou du Médoc.")
    }

    @Parameter(title: "Lieu")
    var target: SpotEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        SpotSelectionStorage().save(target.id)
        return .result()
    }
}

/// Opens Estran from a Spotlight activity hit (e.g. « surf »).
///
/// `AppModel.applyIntentSelectionIfNeeded()` consumes the persisted activity
/// when the app comes to the foreground, so a warm app applies the choice
/// without relaunching; the language-model and the decision stay in the app, no
/// second path is introduced here.
struct OpenActivityIntent: OpenIntent, TargetContentProvidingIntent {
    static var title: LocalizedStringResource {
        "Ouvrir l'activité"
    }

    static var description: IntentDescription {
        IntentDescription("Ouvre Estran pour une activité côtière.")
    }

    @Parameter(title: "Activité")
    var target: ActivityEntity

    func perform() async throws -> some IntentResult {
        IntentSelectionStorage().save(activity: target.activity)
        return .result()
    }
}

/// The one-shot App Group channel an `OpenIntent` uses to tell the running app
/// which activity it opened.
///
/// The spot has a durable home (`SpotSelectionStorage`, shared with the widget
/// and Siri). The activity does not: a Spotlight hit is an instruction for this
/// launch, not a new default, so the value is written here and **consumed and
/// cleared** by `AppModel.applyIntentSelectionIfNeeded()`. Coming back to the
/// foreground later therefore never re-applies an old hit over the user's chip.
struct IntentSelectionStorage {
    /// Key inside the App Group defaults.
    static let activityKey = "pendingIntentActivityID"

    private let defaults: UserDefaults?

    /// Production storage, backed by the shared App Group.
    init(suiteName: String = EstranAppGroup.identifier) {
        defaults = UserDefaults(suiteName: suiteName)
    }

    /// Injectable storage for tests and previews.
    init(defaults: UserDefaults?) {
        self.defaults = defaults
    }

    /// Records the activity an intent asked for. A later write replaces it: the
    /// last hit is the one the user meant.
    func save(activity: Activity) {
        defaults?.set(activity.rawValue, forKey: Self.activityKey)
    }

    /// Reads and removes the pending activity, so it is applied exactly once.
    /// An unknown raw value is dropped rather than mapped to a default activity:
    /// the app keeps the user's current choice (`Activity.allCases` may shrink
    /// between builds).
    func consumeActivity() -> Activity? {
        guard let raw = defaults?.string(forKey: Self.activityKey) else {
            return nil
        }
        defaults?.removeObject(forKey: Self.activityKey)
        return Activity(rawValue: raw)
    }
}
