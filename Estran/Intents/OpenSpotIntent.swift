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
/// Persisting the activity into `AppModel` is out of scope for the intents
/// folder: there is no App Group activity key today. The intent opens the app
/// and reports the chosen activity id in `contentIdentifier`.
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
        .result()
    }
}
