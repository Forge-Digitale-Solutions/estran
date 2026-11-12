import AppIntents
import EstranCore
import Foundation
import SwiftUI

/// Answers « C'est le bon moment ? » from the snapshot the app already wrote.
///
/// No engine, no network: the intent reads the same App Group snapshot as the
/// widgets. Without one it asks the user to open the app rather than guessing,
/// and when the snapshot covers another spot or activity it says so instead of
/// answering for the wrong combination. The spoken dialog and the glass snippet
/// share `IntentAnswer` so Siri never disagrees with the home card.
struct AnswerIntent: AppIntent {
    static var title: LocalizedStringResource {
        "C'est le bon moment ?"
    }

    static var description: IntentDescription {
        IntentDescription(
            "Répond avec les conditions qu'Estran a déjà calculées pour un lieu et une activité.")
    }

    @Parameter(title: "Lieu")
    var spot: SpotEntity?

    @Parameter(title: "Activité")
    var activity: ActivityEntity?

    init() {}

    init(spot: SpotEntity? = nil, activity: ActivityEntity? = nil) {
        self.spot = spot
        self.activity = activity
    }

    init(activity: Activity) {
        spot = nil
        self.activity = ActivityEntity(activity: activity)
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let spotID = spot?.id
            ?? SpotSelectionStorage().load()
            ?? SpotCatalog.defaultSpot.id
        let snapshot = WidgetSnapshot.load(forSpotID: spotID)
        let text = resolvedText(for: snapshot)
        return .result(
            dialog: IntentDialog(stringLiteral: text),
            view: IntentAnswerSnippet(text: text, snapshot: matchingSnapshot(snapshot)))
    }

    /// Pure dialog mapping used by tests and by `perform`.
    func resolvedText(for snapshot: WidgetSnapshot?) -> String {
        // Not offered is independent of the snapshot: surf at Arcachon-Eyrac is
        // answered the same sentence whether or not a snapshot exists, and never
        // with Oui/Non (owner decision 2026-11-12).
        if let spot, let activity, !spot.spot.supports(activity.activity) {
            return ActivityOffer.notOfferedSentence(activity: activity.activity, spot: spot.spot)
        }

        guard let snapshot else {
            return IntentAnswer.text(for: nil)
        }

        if let spot, spot.id != snapshot.spotID {
            return IntentAnswer.notReady(
                spot: spot.name,
                activity: activity?.activity ?? snapshot.activity)
        }
        if let activity, activity.activity != snapshot.activity {
            return IntentAnswer.notReady(
                spot: snapshot.spotName,
                activity: activity.activity)
        }

        return IntentAnswer.text(for: snapshot)
    }

    /// Snippet shows the snapshot only when it answers the requested combo.
    private func matchingSnapshot(_ snapshot: WidgetSnapshot?) -> WidgetSnapshot? {
        guard let snapshot else { return nil }
        if let spot, let activity, !spot.spot.supports(activity.activity) {
            return nil
        }
        if let spot, spot.id != snapshot.spotID {
            return nil
        }
        if let activity, activity.activity != snapshot.activity {
            return nil
        }
        return snapshot
    }
}

/// French App Shortcuts: every phrase includes `.applicationName` (tutoiement).
struct EstranShortcuts: AppShortcutsProvider {
    /// Phrase shapes kept as plain strings so unit tests can assert every
    /// shortcut mentions `.applicationName` without the App Intents runtime.
    static let phraseTemplates: [String] = [
        "C'est un bon moment pour (.applicationName) ?",
        "(.applicationName), c'est bon pour la pêche à pied ?",
        "(.applicationName), c'est bon pour la baignade ?",
        "Je peux faire du surf à (.$spot) avec (.applicationName) ?",
        "(.applicationName), je peux sortir à (.$spot) ?"
    ]

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AnswerIntent(),
            phrases: [
                "C'est un bon moment pour \(.applicationName) ?",
                "\(.applicationName), c'est le bon moment ?",
                "Je peux faire du surf à \(\.$spot) avec \(.applicationName) ?",
                "\(.applicationName), je peux sortir à \(\.$spot) ?"
            ],
            shortTitle: "Bon moment",
            systemImageName: "checkmark.circle")
        AppShortcut(
            intent: AnswerIntent(activity: .shoreFishing),
            phrases: [
                "\(.applicationName), c'est bon pour la pêche à pied ?",
                "Est-ce que je peux pêcher à pied avec \(.applicationName) ?"
            ],
            shortTitle: "Pêche à pied",
            systemImageName: "fish")
        AppShortcut(
            intent: AnswerIntent(activity: .swimming),
            phrases: [
                "\(.applicationName), c'est bon pour la baignade ?",
                "Comment est la baignade avec \(.applicationName) ?"
            ],
            shortTitle: "Baignade",
            systemImageName: "figure.pool.swim")
        AppShortcut(
            intent: AnswerIntent(activity: .surfing),
            phrases: [
                "\(.applicationName), c'est bon pour le surf ?",
                "Je peux surfer avec \(.applicationName) ?"
            ],
            shortTitle: "Surf",
            systemImageName: "figure.surfing")
    }

    static var shortcutTileColor: ShortcutTileColor {
        .blue
    }
}
