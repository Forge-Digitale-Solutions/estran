import EstranCore
import Foundation

/// What Siri and Shortcuts say, derived from the snapshot the app already wrote.
///
/// The mapping is a pure function of `WidgetSnapshot?` so it is testable without
/// the App Intents runtime. There is no engine here and no network: a missing
/// snapshot is a sentence, never a guess, and swimming is always a level plus
/// the year-round warning, never a `Oui` (`ARCHITECTURE_PLAN.md` §7.3).
enum IntentAnswer {
    /// The sentence spoken for a snapshot, or for its absence.
    static func text(for snapshot: WidgetSnapshot?) -> String {
        guard let snapshot else {
            return "Ouvre Estran pour charger les conditions."
        }

        // Not offered is a fact, not a verdict and not stale data: it is spoken
        // as-is, never turned into a `Non`.
        if snapshot.isNotOffered {
            return snapshot.answer
        }

        let answer = if snapshot.isUnavailable {
            "Données indisponibles pour \(snapshot.spotName)."
        } else if snapshot.activity == .swimming {
            swimmingSentence(for: snapshot)
        } else if snapshot.isGo {
            "Oui à \(snapshot.spotName) : \(sentenceAnswer(snapshot.answer))."
        } else {
            "Non à \(snapshot.spotName) : \(sentenceAnswer(snapshot.answer))."
        }

        let spoken = snapshot.isStale
            ? "Ces données datent de plus de deux heures. " + answer
            : answer
        return withCaution(spoken, for: snapshot)
    }

    /// The sentence for a requested spot/activity the snapshot does not cover.
    ///
    /// Saying « pas encore prêtes » is honest: the app has not computed that
    /// combination, so answering from another one would be a fabricated verdict.
    static func notReady(spot: String, activity: Activity) -> String {
        "Les données ne sont pas encore prêtes pour \(activity.displayName) "
            + "à \(spot). Ouvre Estran pour charger les conditions."
    }

    /// Baignade: the level, then the permanent warning. Never « Oui », never a
    /// go-sounding sentence, even when the currents are estimated low.
    private static func swimmingSentence(for snapshot: WidgetSnapshot) -> String {
        let level = snapshot.swimmingAdvisory?.level ?? .unknown
        let region = snapshot.swimmingAdvisory?.region
            ?? SpotCatalog.spot(id: snapshot.spotID)?.region
            ?? SpotCatalog.defaultSpot.region
        let warning = snapshot.swimmingAdvisory?.warning ?? level.warning(for: region)
        return "Baignade à \(snapshot.spotName). \(level.label). \(warning)"
    }

    /// The snapshot stores a phrase without its final period (the widget draws
    /// it as a subtitle). Strip a stray one so the spoken sentence has exactly
    /// one full stop.
    private static func sentenceAnswer(_ answer: String) -> String {
        var text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasSuffix(".") {
            text.removeLast()
        }
        return text
    }

    /// Appends the selected activity's caution (night, light rain, the Bassin
    /// passes) from the snapshot's own line, so Siri never drops a caution the
    /// widget and the app show. Swimming already speaks its baïnes warning, so
    /// it is never doubled. No line, no caution invented.
    private static func withCaution(_ sentence: String, for snapshot: WidgetSnapshot) -> String {
        guard snapshot.activity != .swimming,
              let warning = snapshot.lines
                  .first(where: { $0.activity == snapshot.activity })?
                  .warning,
              !warning.isEmpty
        else {
            return sentence
        }
        return "\(sentence) \(warning)"
    }
}
