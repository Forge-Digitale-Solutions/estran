import EstranCore
import SwiftUI
import WidgetKit

/// Type for the three Lock Screen families.
///
/// One step above the app's caption scale, and rounded for the answer. The
/// accessory slots render at 1× and the Lock Screen desaturates them into a
/// luminance mask, where 11 pt caption2 lines at 75 % opacity melted into the
/// wallpaper (owner feedback on build 5: the tiles and the Lock Screen widgets
/// were there, but nothing readable was left). Hierarchy is built from size and
/// weight, not from opacity: only the least important line is `.secondary`.
private enum AccessoryType {
    /// « Surf · Pointe de Grave ».
    static let title = Font.system(.footnote).weight(.semibold)
    /// « Oui », « Non », « Modérés ».
    static let answer = Font.system(.headline, design: .rounded)
    /// The circular slot has ~72 pt: one step down from the rectangular answer.
    static let circleAnswer = Font.system(.body, design: .rounded).weight(.bold)
    /// The answer's detail, or the honest placeholder.
    static let detail = Font.system(.footnote)
    /// The circular slot's second word (« Baïnes », « Surf »).
    static let circleLabel = Font.system(.caption).weight(.semibold)
    /// Icons sit on the text baseline, never larger than the words.
    static let glyph = Font.system(.caption)
}

/// Lock Screen inline widget (`accessoryInline`).
///
/// One line, shared with the date: « Pêche : Oui · 14 h 00 », « Baignade :
/// courants modérés », or « Estran : — · Ouvre Estran » when stale/missing. The
/// system truncates rather than wraps here, so each string is kept inside the
/// ~280 pt the inline slot gets on a 6.3″ iPhone.
struct GoAccessoryInlineView: View {
    let entry: GoEntry

    var body: some View {
        content
            .lineLimit(1)
    }

    @ViewBuilder
    private var content: some View {
        if entry.isSwimming {
            if entry.isEmpty || entry.isStale {
                Label(
                    "Baignade : baïnes · —",
                    systemImage: "exclamationmark.triangle.fill")
            } else {
                // No trailing « · Baïnes »: the level plus the warning glyph
                // already say it, and the extra segment pushed the line past
                // the slot (it rendered as « courants modérés ·… »).
                Label(
                    "Baignade : courants \(entry.resolvedSwimmingLevel.shortTitle)",
                    systemImage: "exclamationmark.triangle.fill")
            }
        } else if entry.isEmpty || entry.isStale {
            Label("Estran : — · Ouvre Estran", systemImage: "water.waves")
        } else if entry.isNotOffered {
            Label(
                "\(entry.shortActivityLabel) : pas proposé",
                systemImage: entry.activitySymbol)
        } else if entry.isUnavailable {
            Label(
                "\(entry.shortActivityLabel) : — · Indisponible",
                systemImage: "exclamationmark.triangle.fill")
        } else {
            let verdict = entry.isGo ? "Oui" : "Non"
            Label(
                "\(entry.shortActivityLabel) : \(verdict) · \(inlineDetail)",
                systemImage: entry.activitySymbol)
        }
    }

    /// The detail, shortened to what fits: a window keeps its start
    /// (« 14 h 00 à 17 h 30 » → « 14 h 00 »), anything else stays whole.
    ///
    /// The end of a window is not a value lost — the rectangular widget and the
    /// app both show the full range; the inline slot is a glance, not a plan.
    private var inlineDetail: String {
        let separator = " à "
        guard entry.detail.contains(separator),
              let start = entry.detail.components(separatedBy: separator).first,
              !start.isEmpty
        else {
            return entry.detail
        }
        return start
    }
}

/// Lock Screen circular widget (`accessoryCircular`).
///
/// Shows the verdict or swimming risk + « Baïnes » over the system backdrop.
/// The backdrop comes from `containerBackground` (see `GoWidgetView`), never
/// from a view drawn here: inside the content it is composited into the
/// luminance mask and paints over the very text it was meant to sit behind.
///
/// Never shows « Oui » for swimming (Invariant 1), and renders « — » when
/// missing or stale (Invariant 3).
struct GoAccessoryCircularView: View {
    let entry: GoEntry

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: symbol)
                .font(AccessoryType.glyph)
                .widgetAccentable()
                .accessibilityHidden(true)

            Text(answer)
                .font(AccessoryType.circleAnswer)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetAccentable()

            Text(secondLine)
                .font(AccessoryType.circleLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
    }

    private var symbol: String {
        if entry.isSwimming {
            return "exclamationmark.triangle.fill"
        }
        if entry.isEmpty || entry.isStale {
            return "water.waves"
        }
        return entry.verdictSymbol
    }

    private var answer: String {
        if entry.isSwimming {
            guard !entry.isEmpty, !entry.isStale else { return "—" }
            return entry.resolvedSwimmingLevel.shortTitle.capitalized
        }
        if entry.isEmpty || entry.isStale {
            return "—"
        }
        if entry.isNotOffered {
            return entry.shortActivityLabel
        }
        if entry.isUnavailable {
            return "—"
        }
        return entry.isGo ? "Oui" : "Non"
    }

    private var secondLine: String {
        if entry.isSwimming {
            return entry.isEmpty || entry.isStale ? "Ouvre Estran" : "Baïnes"
        }
        if entry.isEmpty || entry.isStale {
            return "Ouvre Estran"
        }
        if entry.isNotOffered {
            return "pas proposé"
        }
        return entry.shortActivityLabel
    }

    /// Spoken sentence: the level or verdict, the spot, and the warning the
    /// slot cannot draw. Never « Oui » for swimming.
    private var spokenLabel: String {
        if entry.isSwimming {
            guard !entry.isEmpty, !entry.isStale else {
                return "Baignade : danger baïnes toute l'année. Données indisponibles, "
                    + "ouvre Estran."
            }
            return "Baignade à \(entry.title) : courants \(entry.resolvedSwimmingLevel.shortTitle). "
                + "Danger baïnes toute l'année."
        }
        if entry.isEmpty || entry.isStale {
            return "Estran : —. Ouvre Estran pour charger les conditions."
        }
        if entry.isNotOffered {
            return "\(entry.activityDisplayName) non proposé à \(entry.title)."
        }
        if entry.isUnavailable {
            return "\(entry.activityDisplayName) à \(entry.title) : données indisponibles."
        }
        let verdict = entry.isGo ? "Oui" : "Non"
        return "\(verdict), \(entry.activityDisplayName) à \(entry.title). \(entry.detail)"
    }
}

/// Lock Screen rectangular widget (`accessoryRectangular`).
///
/// Three lines, in the order the owner reads them: which spot and activity,
/// the answer, then its detail or the honest placeholder. Swimming has no
/// answer, only a level and the year-round baïnes warning.
struct GoAccessoryRectangularView: View {
    let entry: GoEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            titleLine
            answerLine
            detailLine
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// « Surf · Pointe de Grave », « Baignade · Pointe de Grave », or the spot
    /// alone for the bare placeholder.
    ///
    /// One line, scaled down rather than wrapped: a wrapped spot name pushed the
    /// answer out of the 76 pt slot on the real Lock Screen.
    private var titleLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: titleSymbol)
                .font(AccessoryType.glyph)
                .accessibilityHidden(true)
            Text(title)
                .font(AccessoryType.title)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    /// The answer, in the accent group so the tint lands where the eye goes.
    private var answerLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: answerSymbol)
                .font(AccessoryType.glyph)
                .accessibilityHidden(true)
            Text(answer)
                .font(AccessoryType.answer)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .widgetAccentable()
    }

    /// The detail, or the placeholder sentence. `.secondary` only here: it is
    /// the one line the Lock Screen is allowed to dim.
    private var detailLine: some View {
        Text(detail)
            .font(AccessoryType.detail)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private var titleSymbol: String {
        if entry.isSwimming {
            return "exclamationmark.triangle.fill"
        }
        if entry.isEmpty || entry.isStale {
            return "water.waves"
        }
        return entry.activitySymbol
    }

    private var title: String {
        if entry.isEmpty || entry.isStale {
            return entry.title
        }
        return "\(accessoryActivityLabel) · \(entry.title)"
    }

    private var answerSymbol: String {
        if entry.isSwimming {
            return entry.resolvedSwimmingLevel.symbolName
        }
        return entry.verdictSymbol
    }

    /// Never « Oui » for swimming: the level takes the answer's place.
    private var answer: String {
        if entry.isSwimming {
            guard !entry.isEmpty, !entry.isStale else { return "—" }
            return entry.resolvedSwimmingLevel.title
        }
        if entry.isEmpty || entry.isStale {
            return "—"
        }
        if entry.isNotOffered {
            return "Pas proposé"
        }
        if entry.isUnavailable {
            return "—"
        }
        return entry.isGo ? "Oui" : "Non"
    }

    private var detail: String {
        if entry.isSwimming {
            guard !entry.isEmpty, !entry.isStale else { return "Ouvre Estran" }
            return "Danger baïnes toute l'année"
        }
        if entry.isEmpty || entry.isStale {
            return entry.isStale ? "Plus de 2 h · Ouvre Estran" : "Ouvre Estran"
        }
        if entry.isUnavailable {
            return "Données indisponibles"
        }
        return entry.detail
    }

    /// « Baignade » rather than the app chip's « Bain »: the Lock Screen has no
    /// segmented control to explain the abbreviation, and this line is the only
    /// place the slot can name the activity.
    private var accessoryActivityLabel: String {
        entry.isSwimming ? Activity.swimming.displayName : entry.shortActivityLabel
    }
}
