import EstranCore
import SwiftUI

/// Frame 02 — the five activity rows of the spot detail.
///
/// One card, one row per `ActivityOverview` in `Activity.allCases` order, and
/// one answer per row:
/// - `Oui` shows the window in green with a check; without a window it says
///   « Créneau à confirmer » rather than inventing a time;
/// - `Non` shows the short reason in coral with a cross;
/// - a data gap says « Données indisponibles » and never a `Non`
///   (`AGENTS.md` invariant 4);
/// - **swimming never shows Oui/Non**: it shows the current risk level on every
///   state, with its year-round warning (`AGENTS.md` invariant 1).
///
/// Each row is one accessibility element, at least 44 pt tall, and reflows to
/// name-then-answer at large sizes instead of truncating (`DESIGN_REFERENCE.md`
/// §2.1, AX5).
struct ActivityOverviewList: View {
    let overviews: [ActivityOverview]
    let timeZone: TimeZone

    var body: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xs) {
            ForEach(overviews) { overview in
                ActivityOverviewRow(overview: overview, timeZone: timeZone)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(OceanSpacing.md)
        .oceanGlassCard(cornerRadius: OceanGlass.cardCornerRadius)
    }
}

// MARK: - Row

private struct ActivityOverviewRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let overview: ActivityOverview
    let timeZone: TimeZone

    /// Year-round warning of the swimming row. The list has no `Region`, so it
    /// stays coast-neutral: baïnes and tidal currents are dangerous on both.
    private static let swimmingWarning =
        "Baïnes et courants dangereux toute l'année."

    var body: some View {
        content
            .padding(.horizontal, OceanSpacing.sm)
            .padding(.vertical, OceanSpacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: OceanGlass.minimumTapHeight, alignment: .leading)
            .oceanConcentricInset(minimumRadius: 10)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(answer.spoken)
            .animation(
                OceanGlass.animation(.smooth, reduceMotion: reduceMotion),
                value: answer.text)
    }

    @ViewBuilder
    private var content: some View {
        if reflowed {
            stackedContent
        } else {
            ViewThatFits(in: .horizontal) {
                VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
                    HStack(alignment: .firstTextBaseline, spacing: OceanSpacing.sm) {
                        activityName
                            .fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: OceanSpacing.xs)
                        answerLabel(alignment: .trailing)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    warningLine
                }
                stackedContent
            }
        }
    }

    private var stackedContent: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
            activityName
            answerLabel(alignment: .leading)
            warningLine
        }
    }

    private var activityName: some View {
        HStack(alignment: .firstTextBaseline, spacing: OceanSpacing.sm) {
            Image(systemName: overview.activity.symbolName)
                .font(OceanTypography.body)
                .foregroundStyle(OceanPalette.sand)
                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                .accessibilityHidden(true)

            Text(overview.activity.displayName)
                .font(OceanTypography.body)
                .foregroundStyle(OceanPalette.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func answerLabel(alignment: TextAlignment) -> some View {
        Label {
            Text(answer.text)
                .multilineTextAlignment(alignment)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(reduceMotion ? .identity : .numericText())
        } icon: {
            Image(systemName: answer.symbolName)
                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                .accessibilityHidden(true)
        }
        .font(OceanTypography.body)
        .foregroundStyle(answer.color)
    }

    /// The swimming warning is permanent, so it is drawn under the answer on
    /// every state, never truncated and never swapped for the level.
    @ViewBuilder
    private var warningLine: some View {
        if let warning = answer.warning {
            Text(warning)
                .font(OceanTypography.caption)
                .foregroundStyle(OceanPalette.sand)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var reflowed: Bool {
        dynamicTypeSize >= .xxxLarge
    }

    // MARK: Answer

    /// The answer of one row: what is drawn, in which colour, and what VoiceOver
    /// reads. Colour is never the only signal — every state carries a glyph.
    private var answer: ActivityRowAnswer {
        let name = overview.activity.displayName
        // The permanent Bassin boating caution, or `nil` for any other row.
        let caution = ActivityCaution.caution(activity: overview.activity, spot: overview.decision.spot)

        // Swimming first: no state may fall through to Oui/Non.
        if overview.activity == .swimming {
            let level = SwimmingRiskLevel(decision: overview.decision)
            return ActivityRowAnswer(
                text: level.label,
                symbolName: level.symbolName,
                color: OceanPalette.swimmingRiskText(level),
                warning: Self.swimmingWarning,
                spoken: Self.spoken([name, level.label, Self.swimmingWarning]))
        }

        if overview.isUnavailable {
            return ActivityRowAnswer(
                text: "Données indisponibles",
                symbolName: "exclamationmark.triangle.fill",
                color: OceanPalette.unavailable,
                warning: caution,
                spoken: spokenWithCaution([name, "Données indisponibles"], caution: caution))
        }

        if overview.decision.go {
            guard let window = overview.current?.window ?? overview.upcoming?.window else {
                return ActivityRowAnswer(
                    text: "Créneau à confirmer",
                    symbolName: "clock",
                    color: OceanPalette.sand,
                    warning: caution,
                    spoken: spokenWithCaution([name, "Oui", "Créneau à confirmer"], caution: caution))
            }
            let range = FrenchFormat.range(window, in: timeZone)
            return ActivityRowAnswer(
                text: range,
                symbolName: "checkmark.circle.fill",
                color: OceanPalette.ouiOnGlass,
                warning: caution,
                spoken: spokenWithCaution([name, "Oui", range], caution: caution))
        }

        return ActivityRowAnswer(
            text: Self.phrase(overview.decision.reason),
            symbolName: "xmark.circle.fill",
            color: OceanPalette.nonOnGlass,
            warning: caution,
            spoken: spokenWithCaution([name, "Non", Self.phrase(overview.decision.reason)], caution: caution))
    }

    /// Joins the parts as one VoiceOver sentence, with the boating caution
    /// appended when present, and a single closing period.
    private func spokenWithCaution(_ parts: [String], caution: String?) -> String {
        let all = caution.map { parts + [$0] } ?? parts
        return Self.spoken(all)
    }

    /// « Marge insuffisante. » → « Marge insuffisante » : the row is a label, not
    /// a sentence, and the picker writes it the same way.
    private static func phrase(_ reason: String) -> String {
        var text = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasSuffix(".") {
            text.removeLast()
        }
        return text
    }

    /// Joins the parts as one VoiceOver sentence, with a single closing period.
    private static func spoken(_ parts: [String]) -> String {
        parts
            .map { $0.hasSuffix(".") ? String($0.dropLast()) : $0 }
            .joined(separator: ". ") + "."
    }
}

private struct ActivityRowAnswer {
    let text: String
    let symbolName: String
    let color: Color
    /// Secondary permanent line, swimming only.
    let warning: String?
    let spoken: String
}

// MARK: - Preview

#Preview("Créneaux") {
    ScrollView {
        ActivityOverviewList(
            overviews: PreviewData.overviews,
            timeZone: PreviewData.timeZone)
            .padding(OceanSpacing.md)
    }
    .background { OceanBackdrop() }
}

/// Five hard-coded rows — a `Oui` with a window, a `Non`, an unavailable state,
/// a `Oui` without a confirmed window and swimming — so the card can be
/// inspected without the app or the tide dataset.
private enum PreviewData {
    static let timeZone = TimeZone(identifier: "Europe/Paris")
        ?? TimeZone(secondsFromGMT: 0)
        ?? .current

    static let overviews: [ActivityOverview] = [
        ActivityOverview(
            activity: .shoreFishing,
            decision: decision(
                .shoreFishing,
                go: true,
                reason: "C'est bon pour la pêche à pied."),
            current: ActivitySlot(
                activity: .shoreFishing,
                window: DateInterval(
                    start: date(hour: 13, minute: 10),
                    end: date(hour: 15, minute: 40)),
                score: 0.82,
                go: true),
            upcoming: nil),
        ActivityOverview(
            activity: .surfing,
            decision: decision(.surfing, go: false, reason: "Trop petit."),
            current: nil,
            upcoming: nil),
        ActivityOverview(
            activity: .boating,
            decision: decision(
                .boating,
                go: false,
                reason: "Données indisponibles.",
                blockers: [.dataUnavailable]),
            current: nil,
            upcoming: nil),
        ActivityOverview(
            activity: .walking,
            decision: decision(
                .walking,
                go: true,
                reason: "C'est bon pour la balade."),
            current: nil,
            upcoming: nil),
        ActivityOverview(
            activity: .swimming,
            decision: decision(
                .swimming,
                go: false,
                reason: "Courants forts.",
                blockers: [.strongCurrent]),
            current: nil,
            upcoming: nil)
    ]

    static func decision(
        _ activity: Activity,
        go: Bool,
        reason: String,
        blockers: [ActivityBlocker] = []) -> GoDecision
    {
        GoDecision(
            activity: activity,
            spot: SpotCatalog.arcachonEyrac,
            go: go,
            score: go ? 0.82 : 0.35,
            reason: reason,
            reasonSource: .template,
            nextGoodWindow: nil,
            computedAt: date(hour: 12),
            blockers: blockers)
    }

    static func date(hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 28
        components.hour = hour
        components.minute = minute
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }
}
