import EstranCore
import Foundation
import SwiftUI

/// Frame 03 — the activity picker sheet.
///
/// One scrollable glass panel: the bar (« Activité », close, confirm) stays
/// pinned, then « Tu fais quoi ? » and the five rows scroll as a single column.
/// Each row repeats the answer the spot detail gives for the same activity, so
/// the picker never argues with the screen it came from.
///
/// **Swimming has no verdict here either.** Its row shows the permanent warning
/// plus the tidal-current level, in `sand` or the coral glass text — never
/// `oui` green (`AGENTS.md` invariant 1, `DESIGN_REFERENCE.md` §3.3).
///
/// **Selection is never colour alone.** The selected row keeps its turquoise
/// 2 pt border *and* a filled check circle on the trailing edge, and carries the
/// `.isSelected` accessibility trait.
struct ActivityPickerView: View {
    let spotName: String
    let overviews: [ActivityOverview]
    let selection: Activity
    let timeZone: TimeZone
    let onSelect: (Activity) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Flips once, on appear: staggers the entrance of the activity rows.
    @State private var tilesAppeared = false

    /// A control, not a text container: it stays at the HIG minimum at every size.
    private let barButtonSize: CGFloat = OceanGlass.minimumTapHeight
    /// The 17 pt of a system bar button: chrome, not copy, so it never scales.
    private let barGlyphSize: CGFloat = 17
    /// The activity square grows with the text it sits next to, up to a cap.
    @ScaledMetric(relativeTo: .body) private var iconTileSize: CGFloat = 44
    /// The cap: at AX5 an uncapped glyph tile doubles the height of the row.
    private var iconTileSide: CGFloat {
        min(iconTileSize, 64)
    }

    var body: some View {
        VStack(spacing: 0) {
            bar
            ScrollView {
                VStack(alignment: .leading, spacing: OceanSpacing.lg) {
                    titleBlock
                    rows
                }
                .padding(.horizontal, OceanSpacing.md)
                .padding(.top, OceanSpacing.sm)
                .padding(.bottom, OceanSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background { OceanBackdrop() }
        // The Taptic Engine confirms a real selection before the sheet closes.
        .sensoryFeedback(.selection, trigger: selection)
    }

    // MARK: - Bar

    /// Close on the left, confirm on the right, title centred between them.
    /// Both buttons dismiss: choosing a row is the only thing that changes the
    /// selection, so the check is a plain « j'ai fini ».
    private var bar: some View {
        HStack(spacing: OceanSpacing.xs) {
            barButton(systemImage: "xmark", label: "Fermer")
            Spacer(minLength: OceanSpacing.xxs)
            Text("Activité")
                .font(OceanTypography.bodyEmphasized)
                .foregroundStyle(OceanPalette.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: OceanSpacing.xxs)
            barButton(systemImage: "checkmark", label: "Terminer")
        }
        .padding(.horizontal, OceanSpacing.md)
        .padding(.top, OceanSpacing.sm)
        .padding(.bottom, OceanSpacing.xs)
    }

    private func barButton(systemImage: String, label: String) -> some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: barGlyphSize, weight: .semibold))
                .foregroundStyle(OceanPalette.white)
                .frame(width: barButtonSize, height: barButtonSize)
                .contentShape(Circle())
                .oceanGlassCircle(interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
            Text("Tu fais quoi ?")
                .font(OceanTypography.largeTitle)
                .foregroundStyle(OceanPalette.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("On te dit si c'est le bon moment, spot par spot.")
                .font(OceanTypography.subtitle)
                .foregroundStyle(OceanPalette.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Rows

    private var rows: some View {
        GlassEffectContainer(spacing: OceanSpacing.sm) {
            VStack(spacing: OceanSpacing.sm) {
                ForEach(Array(overviews.enumerated()), id: \.element.id) { index, overview in
                    row(for: overview)
                        .modifier(PickerTileEntrance(index: index, appeared: tilesAppeared))
                }
            }
        }
        .onAppear { tilesAppeared = true }
    }

    private func row(for overview: ActivityOverview) -> some View {
        let isSelected = overview.activity == selection
        return Button {
            onSelect(overview.activity)
            dismiss()
        } label: {
            rowLabel(for: overview, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySentence(for: overview))
        .accessibilityHint("Choisit cette activité")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }

    private func rowLabel(for overview: ActivityOverview, isSelected: Bool) -> some View {
        rowContent(for: overview, isSelected: isSelected)
            .padding(OceanSpacing.md)
            .frame(
                maxWidth: .infinity,
                minHeight: OceanGlass.minimumTapHeight,
                alignment: .leading)
            .contentShape(Rectangle())
            // The ring is drawn *before* the glass: `glassEffect` composites its
            // own layer over anything added after it, so an overlay applied on
            // the finished card is never visible.
            .overlay {
                if isSelected {
                    RoundedRectangle(
                        cornerRadius: OceanGlass.tileCornerRadius,
                        style: .continuous)
                        .strokeBorder(OceanPalette.turquoise, lineWidth: 2)
                }
            }
            .oceanGlassCard(cornerRadius: OceanGlass.tileCornerRadius)
    }

    /// Side by side at normal sizes. From `.accessibility1` up the glyph and the
    /// check move above the text so the name and the answer keep the full width
    /// instead of wrapping into a three-word column.
    @ViewBuilder
    private func rowContent(for overview: ActivityOverview, isSelected: Bool) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: OceanSpacing.xs) {
                HStack(spacing: OceanSpacing.xs) {
                    iconTile(for: overview.activity, isSelected: isSelected)
                    Spacer(minLength: OceanSpacing.xxs)
                    selectionMark(isSelected: isSelected)
                }
                textBlock(for: overview)
            }
        } else {
            HStack(alignment: .center, spacing: OceanSpacing.sm) {
                iconTile(for: overview.activity, isSelected: isSelected)
                textBlock(for: overview)
                Spacer(minLength: OceanSpacing.xs)
                selectionMark(isSelected: isSelected)
            }
        }
    }

    private func iconTile(for activity: Activity, isSelected: Bool) -> some View {
        Image(systemName: activity.symbolName)
            // Proportional to the square, not to `.body`: an uncapped glyph
            // outgrows the tile at AX5 and spills over its rounded corners.
            .font(.system(size: iconTileSide * 0.42, weight: .semibold))
            .foregroundStyle(isSelected ? OceanPalette.turquoise : OceanPalette.sand)
            .frame(width: iconTileSide, height: iconTileSide)
            .background(
                OceanPalette.white.opacity(0.12),
                in: RoundedRectangle(
                    cornerRadius: OceanGlass.tileCornerRadius,
                    style: .continuous))
            .accessibilityHidden(true)
    }

    /// Filled when selected, hollow otherwise; the row border and the
    /// `.isSelected` trait say the same thing in two other ways.
    private func selectionMark(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(OceanTypography.metricValue)
            .foregroundStyle(
                isSelected ? OceanPalette.turquoise : OceanPalette.white.opacity(0.35))
            .accessibilityHidden(true)
    }

    private func textBlock(for overview: ActivityOverview) -> some View {
        let answer = ActivityAnswer(overview: overview, timeZone: timeZone)
        return VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
            Text(overview.activity.displayName)
                .font(OceanTypography.bodyEmphasized)
                .foregroundStyle(OceanPalette.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(spotName)
                .font(OceanTypography.caption)
                .foregroundStyle(OceanPalette.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            answerView(answer)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func answerView(_ answer: ActivityAnswer) -> some View {
        if let symbol = answer.primarySymbol {
            Label(answer.primary, systemImage: symbol)
                .font(OceanTypography.button)
                .foregroundStyle(answer.primaryColor)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(answer.primary)
                .font(OceanTypography.button)
                .foregroundStyle(answer.primaryColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        if let secondary = answer.secondary {
            Text(secondary)
                .font(OceanTypography.button)
                .foregroundStyle(answer.secondaryColor ?? OceanPalette.sand)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// What VoiceOver reads: the name, the spot, then the very lines the row
    /// draws. Built from `ActivityAnswer` so the spoken and the visible answer
    /// cannot drift.
    private func accessibilitySentence(for overview: ActivityOverview) -> String {
        let answer = ActivityAnswer(overview: overview, timeZone: timeZone)
        return [overview.activity.displayName, spotName, answer.spoken]
            .joined(separator: ", ")
    }
}

// MARK: - The answer of one row

/// The one or two lines a row draws under the spot name, derived once so the
/// visual answer and the accessibility label are the same words.
private struct ActivityAnswer {
    /// The permanent swimming warning, word for word (`DESIGN_REFERENCE.md` §3.3).
    private static let swimmingWarning = "Baïnes et courants : risque toute l'année"

    let primary: String
    let primaryColor: Color
    /// Only the swimming warning wears an alert glyph.
    let primarySymbol: String?
    let secondary: String?
    let secondaryColor: Color?

    init(overview: ActivityOverview, timeZone: TimeZone) {
        if overview.activity == .swimming {
            // Never Oui, never Non, never green: a warning and a level.
            let level = SwimmingRiskLevel(decision: overview.decision)
            primary = Self.swimmingWarning
            primaryColor = OceanPalette.sand
            primarySymbol = "exclamationmark.triangle.fill"
            if level == .unknown {
                // The level itself says the data cannot estimate the currents.
                secondary = level.label
                secondaryColor = OceanPalette.sand
            } else if overview.isUnavailable {
                secondary = "Données indisponibles"
                secondaryColor = OceanPalette.unavailable
            } else {
                secondary = level.label
                secondaryColor = level == .strong
                    ? OceanPalette.nonOnGlass
                    : OceanPalette.sand
            }
            return
        }
        primarySymbol = nil
        secondary = ActivityCaution.caution(activity: overview.activity, spot: overview.decision.spot)
        secondaryColor = OceanPalette.sand

        if overview.isUnavailable {
            primary = "Données indisponibles"
            primaryColor = OceanPalette.unavailable
            return
        }
        if overview.decision.go {
            if let window = overview.current?.window
                ?? overview.upcoming?.window
                ?? overview.decision.nextGoodWindow
            {
                primary = "Oui, \(FrenchFormat.range(window, in: timeZone))"
            } else {
                // A `Oui` with no window is still a `Oui`: never invent a time.
                primary = "Oui"
            }
            primaryColor = OceanPalette.ouiOnGlass
            return
        }
        primary = "Non, \(Self.phrase(overview.decision.reason))"
        primaryColor = OceanPalette.nonOnGlass
    }

    /// « Vent trop fort. » → « vent trop fort », as the frame writes it.
    private static func phrase(_ reason: String) -> String {
        var text = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasSuffix(".") {
            text.removeLast()
        }
        guard let first = text.first else { return text }
        return String(first).lowercased() + String(text.dropFirst())
    }

    /// The row as one spoken sentence.
    var spoken: String {
        guard let secondary else { return primary }
        return "\(primary). \(secondary)"
    }
}

// MARK: - Preview

#Preview("Choix de l'activité") {
    ActivityPickerView(
        spotName: ActivityPickerPreview.spot.name,
        overviews: ActivityPickerPreview.overviews,
        selection: .shoreFishing,
        timeZone: ActivityPickerPreview.spot.timezone,
        onSelect: { _ in })
}

/// Three verdicts and the swimming warning, so the sheet can be inspected
/// without the app, a forecast or a dataset.
private enum ActivityPickerPreview {
    static let spot = SpotCatalog.arcachonEyrac
    private static let now = Date(timeIntervalSince1970: 1_793_000_000)
    private static let afternoon = DateInterval(start: now + 3600, duration: 9000)
    private static let evening = DateInterval(start: now + 5 * 3600, duration: 5400)

    static var overviews: [ActivityOverview] {
        [
            overview(.shoreFishing, go: true, reason: "Bonne pêche.", current: afternoon),
            overview(.surfing, go: true, reason: "Bon surf.", upcoming: evening),
            overview(.boating, go: false, reason: "Vent trop fort."),
            overview(.walking, go: false, reason: "Trop sombre."),
            overview(.swimming, go: false, reason: "Courant trop fort.", blockers: [.strongCurrent])
        ]
    }

    private static func overview(
        _ activity: Activity,
        go: Bool,
        reason: String,
        blockers: [ActivityBlocker] = [],
        current: DateInterval? = nil,
        upcoming: DateInterval? = nil) -> ActivityOverview
    {
        let decision = GoDecision(
            activity: activity,
            spot: spot,
            go: go,
            score: go ? 0.82 : 0.21,
            reason: reason,
            reasonSource: .template,
            nextGoodWindow: current,
            computedAt: now,
            blockers: blockers)
        return ActivityOverview(
            activity: activity,
            decision: decision,
            current: current.map {
                ActivitySlot(activity: activity, window: $0, score: 0.8, go: go)
            },
            upcoming: upcoming.map {
                ActivitySlot(activity: activity, window: $0, score: 0.8, go: go)
            })
    }
}
