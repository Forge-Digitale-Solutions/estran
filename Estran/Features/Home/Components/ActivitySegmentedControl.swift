import EstranCore
import SwiftUI

/// Five-segment activity picker.
///
/// Native `Picker(.segmented)` truncates labels at accessibility sizes, so this
/// control is a horizontal `ScrollView` of glass pills at normal sizes and a
/// `Menu` from `.accessibility1` up, where five huge chips would force a
/// horizontal hunt. Each chip is one VoiceOver element; an unavailable activity
/// says so as its value and carries an icon, never a colour-only cue.
///
/// The chips are interactive iOS 27 glass: every pill is
/// `Glass.regular.interactive()`, so it deflects light under the finger, and the
/// whole bar is one `GlassEffectContainer`. The selected pill is a **droplet**:
/// it carries one fixed `glassEffectID` whichever chip is selected, so the white
/// glass stretches from one chip to the next instead of switching on and off
/// (`docs/design/ios27-opportunities.md`, item 1). Every chip is at least 44 pt
/// tall (early M3 review, points 1 and 5).
///
/// ## Motion and contrast
///
/// - The selection animation runs on the glass only. The label carries
///   `.animation(nil, value: selection)` so it snaps from white to `ink` instead
///   of crossing a ~1.3:1 grey while the tint fades (accessibility report §5.2).
/// - Reduce Motion replaces the droplet's matched geometry with `.identity`: the
///   selection is still visible, it simply does not travel.
/// - Reduce Transparency and Increase Contrast reach the chips through
///   `oceanGlassChip(isSelected:)`, the shared tint-aware surface: opaque
///   `navyInk` (or the white pill) with a border, and the 45 % backing plus the
///   1.5 pt border under Increase Contrast (accessibility report §5.1).
struct ActivitySegmentedControl: View {
    let selection: Activity
    let unavailable: Set<Activity>
    /// The activities the selected spot offers, in `Activity.allCases` order.
    /// Arcachon-Eyrac drops `.surfing`, so the bar shows four chips there.
    let supported: Set<Activity>
    let onSelect: (Activity) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glassNamespace

    /// The single identity the selected pill carries on every chip. Two glass
    /// effects that share an identity inside one `GlassEffectContainer` morph
    /// into each other, which is what makes the selection look like one droplet
    /// of water moving along the bar rather than five pills blinking.
    private static let selectionGlassID = "activity-selection"

    private var activities: [Activity] {
        Activity.allCases.filter { supported.contains($0) }
    }

    var body: some View {
        if dynamicTypeSize >= .accessibility1 {
            // Five huge chips would force a horizontal hunt at AX sizes; the
            // design allows a Menu, and it keeps all five reachable in one tap.
            menu
        } else {
            chips
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: OceanSpacing.xxs) {
                HStack(spacing: OceanSpacing.xxs) {
                    ForEach(activities) { activity in
                        chip(for: activity)
                    }
                }
                .padding(OceanSpacing.xxs)
            }
        }
        // The only animated value of the control is the selection, and it is
        // animated here so the glass travels. `nil` under Reduce Motion makes
        // the change land on its final frame in one pass.
        .animation(
            OceanGlass.animation(
                .spring(response: 0.42, dampingFraction: 0.82),
                reduceMotion: reduceMotion),
            value: selection)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
    }

    private var menu: some View {
        Menu {
            ForEach(activities) { activity in
                Button {
                    onSelect(activity)
                } label: {
                    if activity == selection {
                        Label(
                            activity.displayName,
                            systemImage: activity == .swimming
                                ? "exclamationmark.triangle.fill"
                                : "checkmark")
                    } else if activity == .swimming {
                        Label(activity.displayName, systemImage: "exclamationmark.triangle.fill")
                    } else if unavailable.contains(activity) {
                        Label(activity.displayName, systemImage: "exclamationmark.circle")
                    } else {
                        Text(activity.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: OceanSpacing.xs) {
                Text(selection.displayName)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: OceanSpacing.xs)
                Image(systemName: "chevron.up.chevron.down")
            }
            .font(OceanTypography.button)
            .foregroundStyle(OceanPalette.white)
            .padding(.horizontal, OceanSpacing.sm)
            .padding(.vertical, OceanSpacing.xs)
            .frame(maxWidth: .infinity, minHeight: OceanGlass.minimumTapHeight)
            .oceanGlassCapsule(interactive: true)
        }
        .accessibilityLabel("Activité")
        .accessibilityValue(menuValue)
    }

    /// The menu branch has to carry the same facts as the chips: the selected
    /// activity and, for swimming or a missing dataset, the warning the chip
    /// shows. Both branches share `accessibilityValue(for:isUnavailable:)` so
    /// they cannot drift.
    private var menuValue: String {
        let detail = accessibilityValue(
            for: selection,
            isUnavailable: unavailable.contains(selection))
        return detail.isEmpty ? selection.displayName : "\(selection.displayName), \(detail)"
    }

    private func chip(for activity: Activity) -> some View {
        let isSelected = activity == selection
        let isUnavailable = unavailable.contains(activity)

        return Button {
            onSelect(activity)
        } label: {
            chipLabel(for: activity, isSelected: isSelected, isUnavailable: isUnavailable)
        }
        .buttonStyle(.plain)
        // One identity for the selected pill on every chip: the droplet morphs
        // from the old chip to the new one. The unselected chips keep their own
        // identity so they never merge with the selection. Reduce Motion swaps
        // matched geometry for `.identity`, so the glass is repainted in place.
        .glassEffectID(
            isSelected ? Self.selectionGlassID : activity.rawValue,
            in: glassNamespace)
        .glassEffectTransition(reduceMotion ? .identity : .matchedGeometry)
        .accessibilityLabel(activity.displayName)
        .accessibilityValue(accessibilityValue(for: activity, isUnavailable: isUnavailable))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }

    private func chipLabel(
        for activity: Activity,
        isSelected: Bool,
        isUnavailable: Bool) -> some View
    {
        HStack(spacing: OceanSpacing.xxs) {
            Text(activity.shortLabel)
                .font(OceanTypography.button)
                .fixedSize(horizontal: false, vertical: true)
            if activity == .swimming {
                // Permanent warning: swimming is never a plain activity.
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(OceanTypography.smallLabel)
                    .accessibilityHidden(true)
            } else if isUnavailable {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(OceanTypography.smallLabel)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(isSelected ? OceanPalette.ink : OceanPalette.white)
        // §5.2: the glass may cross-fade, the label must not. Interpolating
        // white → ink over light glass passes through ~1.3:1 grey; with no
        // animation on this subtree the text snaps to its final colour.
        .animation(nil, value: selection)
        .padding(.horizontal, OceanSpacing.sm)
        .padding(.vertical, OceanSpacing.xs)
        .frame(minHeight: OceanGlass.minimumTapHeight)
        .contentShape(Capsule(style: .continuous))
        // The selected pill stays white in every look, so selection is never
        // carried by glass alone. `oceanGlassChip` keeps the app-owned Reduce
        // Transparency and Increase Contrast looks (accessibility report §5.1).
        .oceanGlassChip(isSelected: isSelected)
    }

    private func accessibilityValue(for activity: Activity, isUnavailable: Bool) -> String {
        var parts: [String] = []
        if activity == .swimming {
            parts.append("Avertissement baignade, niveau de risque")
        }
        if isUnavailable {
            parts.append("Données indisponibles")
        }
        return parts.joined(separator: ", ")
    }
}
