import AppIntents
import EstranCore
import SwiftUI
import WidgetKit

/// Control Center control: « Estran : c'est le bon moment ? ».
///
/// Same data path as the widgets: the app writes one `WidgetSnapshot` in the App
/// Group and `body` reads it synchronously — no network, no engine, no async
/// work. Tapping the control only opens Estran; it never answers a decision by
/// itself, and swimming never shows « Oui ».
///
/// No snapshot is a state of its own: the control shows « — », never a
/// fabricated « Non » (invariant 4). The label carries one spoken sentence,
/// because a Control Center tile is read before it is looked at.
struct EstranControl: ControlWidget {
    let kind = "EstranControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            let state = EstranControlState(snapshot: WidgetSnapshot.load())
            ControlWidgetButton(action: OpenEstranIntent()) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.spotName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack(spacing: 2) {
                        Image(systemName: state.symbol)
                            .font(.caption2)
                            .accessibilityHidden(true)
                        Text(state.value)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(state.accessibilityLabel)
            }
            .tint(state.tint)
        }
        .displayName("Estran : c'est le bon moment ?")
        .description("La réponse du spot choisi. Ouvre Estran pour le détail.")
    }
}

/// What the control draws, derived only from the shared snapshot.
///
/// Invariants: swimming is a risk level, never « Oui » (1); a missing value is
/// visible, never a silent « Non » (4). The symbol and the word always travel
/// together, so the tile is never colour-only.
private struct EstranControlState {
    let spotName: String
    let value: String
    let symbol: String
    let tint: Color
    let accessibilityLabel: String

    init(snapshot: WidgetSnapshot?) {
        guard let snapshot else {
            spotName = "Estran"
            value = "—"
            symbol = "minus.circle"
            tint = OceanPalette.unavailable
            accessibilityLabel = "Estran. Aucune donnée. Ouvre l'app pour la réponse."
            return
        }

        spotName = snapshot.spotName

        if snapshot.isUnavailable {
            value = "Indisponible"
            symbol = "questionmark.circle"
            tint = OceanPalette.unavailable
            accessibilityLabel =
                "Estran. \(snapshot.spotName). Données indisponibles. Ouvre l'app pour le détail."
        } else if snapshot.activity == .swimming {
            // No level means no estimate: `unknown` is still a warning, never a
            // verdict. The level's own title is spoken, never a go word.
            let level = snapshot.swimmingAdvisory?.level ?? .unknown
            value = level.title
            symbol = level.symbolName
            tint = OceanPalette.swimmingRisk(level)
            accessibilityLabel =
                "Estran. \(snapshot.spotName). Baignade, \(level.title). Ouvre l'app pour le détail."
        } else {
            value = snapshot.isGo ? "Oui" : "Non"
            symbol = snapshot.isGo ? "checkmark.circle.fill" : "xmark.circle"
            tint = snapshot.isGo ? OceanPalette.oui : OceanPalette.non
            accessibilityLabel = "Estran. \(snapshot.spotName). \(value). Ouvre l'app pour le détail."
        }
    }
}

/// Tapping the control opens Estran. The intent carries no decision: the answer
/// stays on the snapshot the app computed.
struct OpenEstranIntent: AppIntent {
    static var title: LocalizedStringResource {
        "Ouvrir Estran"
    }

    static var supportedModes: IntentModes {
        .foreground
    }

    func perform() async throws -> some IntentResult {
        .result()
    }
}
