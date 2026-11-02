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
/// The chips are real iOS 27 glass (`glassEffect` inside a
/// `GlassEffectContainer`), so adjacent pills merge as the system does. Every
/// chip is at least 44 pt tall (early M3 review, points 1 and 5).
struct ActivitySegmentedControl: View {
    let selection: Activity
    let unavailable: Set<Activity>
    let onSelect: (Activity) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    ForEach(Activity.allCases) { activity in
                        chip(for: activity)
                    }
                }
                .padding(OceanSpacing.xxs)
            }
        }
        .accessibilityElement(children: .contain)
        // The control declares no animation of its own: a selection is a tint
        // change on the glass. Glass in a container can still morph when the
        // transaction carries an animation, so under Reduce Motion the
        // transaction is stripped. With the flag off it is left untouched.
        .transaction { transaction in
            guard reduceMotion else { return }
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    private var menu: some View {
        Menu {
            ForEach(Activity.allCases) { activity in
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
        }
        .oceanGlassCapsule()
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
        let glass: Glass = isSelected
            ? .regular.tint(OceanPalette.white)
            : .regular

        return Button {
            onSelect(activity)
        } label: {
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
            .padding(.horizontal, OceanSpacing.sm)
            .padding(.vertical, OceanSpacing.xs)
            .frame(minHeight: OceanGlass.minimumTapHeight)
            .contentShape(Capsule(style: .continuous))
            .glassEffect(glass, in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(activity.displayName)
        .accessibilityValue(accessibilityValue(for: activity, isUnavailable: isUnavailable))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
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
