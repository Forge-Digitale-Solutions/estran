import AppIntents
import EstranCore
import Foundation

/// The two spots of the catalog, in French, for Siri and Shortcuts.
///
/// The values map to the `EstranCore` identifiers: the app, the widgets and the
/// intents must never disagree on which spot is being answered.
enum SpotChoice: String, AppEnum {
    case pointeDeGrave
    case arcachonEyrac

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Lieu"
    }

    static var caseDisplayRepresentations: [Self: DisplayRepresentation] {
        [
            .pointeDeGrave: DisplayRepresentation(title: "Pointe de Grave"),
            .arcachonEyrac: DisplayRepresentation(title: "Arcachon-Eyrac")
        ]
    }

    var spot: Spot {
        switch self {
        case .pointeDeGrave: SpotCatalog.pointeDeGrave
        case .arcachonEyrac: SpotCatalog.arcachonEyrac
        }
    }
}

/// The five activities, with the same French labels as the app.
enum ActivityChoice: String, AppEnum {
    case shoreFishing
    case surfing
    case boating
    case walking
    case swimming

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Activité"
    }

    static var caseDisplayRepresentations: [Self: DisplayRepresentation] {
        [
            .shoreFishing: DisplayRepresentation(title: "Pêche à pied"),
            .surfing: DisplayRepresentation(title: "Surf"),
            .boating: DisplayRepresentation(title: "Bateau"),
            .walking: DisplayRepresentation(title: "Balade"),
            .swimming: DisplayRepresentation(title: "Baignade")
        ]
    }

    var activity: Activity {
        switch self {
        case .shoreFishing: .shoreFishing
        case .surfing: .surfing
        case .boating: .boating
        case .walking: .walking
        case .swimming: .swimming
        }
    }
}

/// Answers « C'est le bon moment ? » from the snapshot the app already wrote.
///
/// No engine, no network: the intent reads the same App Group snapshot as the
/// widgets. Without one it asks the user to open the app rather than guessing,
/// and when the snapshot covers another spot or activity it says so instead of
/// answering for the wrong combination.
struct AnswerIntent: AppIntent {
    static var title: LocalizedStringResource {
        "C'est le bon moment ?"
    }

    static var description: IntentDescription {
        IntentDescription(
            "Répond avec les conditions qu'Estran a déjà calculées pour un lieu et une activité.")
    }

    @Parameter(title: "Lieu")
    var spot: SpotChoice?

    @Parameter(title: "Activité")
    var activity: ActivityChoice?

    init() {}

    init(spot: SpotChoice? = nil, activity: ActivityChoice? = nil) {
        self.spot = spot
        self.activity = activity
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let snapshot = WidgetSnapshot.load()

        guard let snapshot else {
            return dialog(IntentAnswer.text(for: nil))
        }

        // The snapshot is the only source. A combination it does not cover is
        // an honest « pas encore prêtes », never another activity's answer.
        if let spot, spot.spot.id != snapshot.spotID {
            return dialog(
                IntentAnswer.notReady(
                    spot: spot.spot.name,
                    activity: activity?.activity ?? snapshot.activity))
        }
        if let activity, activity.activity != snapshot.activity {
            return dialog(
                IntentAnswer.notReady(
                    spot: snapshot.spotName,
                    activity: activity.activity))
        }

        return dialog(IntentAnswer.text(for: snapshot))
    }

    private func dialog(_ text: String) -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: text))
    }
}

/// The three Siri phrases: pêche à pied, baignade, and the selected activity.
struct EstranShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AnswerIntent(activity: .shoreFishing),
            phrases: ["\(.applicationName), c'est bon pour la pêche à pied ?"],
            shortTitle: "Pêche à pied",
            systemImageName: "fish")
        AppShortcut(
            intent: AnswerIntent(activity: .swimming),
            phrases: ["\(.applicationName), c'est bon pour la baignade ?"],
            shortTitle: "Baignade",
            systemImageName: "figure.pool.swim")
        AppShortcut(
            intent: AnswerIntent(),
            phrases: ["\(.applicationName), c'est le bon moment ?"],
            shortTitle: "Bon moment",
            systemImageName: "checkmark.circle")
    }

    static var shortcutTileColor: ShortcutTileColor {
        .blue
    }
}
