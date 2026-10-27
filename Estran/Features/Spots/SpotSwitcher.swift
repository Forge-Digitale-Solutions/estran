import EstranCore
import SwiftUI

/// Floating Liquid Glass switcher: **the only place a spot is chosen**.
///
/// Two chips, no list, no third spot, no « bientôt ». Selection is never
/// colour-only: the active chip also carries a check glyph. At accessibility
/// sizes the chips stack, then the control degrades to a `Menu` so it does not
/// eat the map (`DESIGN_REFERENCE.md` §6.1).
///
/// The chips are iOS 27 glass (`glassEffect` in a `GlassEffectContainer`), not
/// a pre-26 material, and every chip is at least 44 pt tall.
struct SpotSwitcher: View {
    let spots: [Spot]
    let selection: Spot
    let onSelect: (Spot) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var announced = false

    var body: some View {
        Group {
            if dynamicTypeSize >= .accessibility3 {
                menu
            } else {
                chips
            }
        }
        .onAppear {
            guard !announced else { return }
            announced = true
            AccessibilityNotification.Announcement(
                "Spot actuel : \(selection.name)").post()
        }
    }

    private var chips: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: OceanSpacing.xs))
            : AnyLayout(HStackLayout(spacing: OceanSpacing.xs))

        return GlassEffectContainer(spacing: OceanSpacing.xs) {
            layout {
                ForEach(spots) { spot in
                    chip(for: spot)
                }
            }
            .padding(OceanSpacing.xs)
        }
        .animation(
            reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85),
            value: selection.id)
    }

    private func chip(for spot: Spot) -> some View {
        let isSelected = spot.id == selection.id
        let glass: Glass = isSelected
            ? .regular.tint(OceanPalette.white)
            : .regular

        return Button {
            onSelect(spot)
        } label: {
            HStack(spacing: OceanSpacing.xxs) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(OceanTypography.smallLabel)
                    .accessibilityHidden(true)
                Text(spot.name)
                    .font(OceanTypography.button)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? OceanPalette.ink : OceanPalette.white)
            .padding(.horizontal, OceanSpacing.sm)
            .padding(.vertical, OceanSpacing.xs)
            .frame(maxWidth: .infinity, minHeight: OceanGlass.minimumTapHeight)
            .contentShape(Capsule(style: .continuous))
            .glassEffect(glass, in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spot.name)
        .accessibilityHint("Affiche les conditions à \(spot.name)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }

    private var menu: some View {
        Menu {
            ForEach(spots) { spot in
                Button {
                    onSelect(spot)
                } label: {
                    if spot.id == selection.id {
                        Label(spot.name, systemImage: "checkmark")
                    } else {
                        Text(spot.name)
                    }
                }
            }
        } label: {
            HStack(spacing: OceanSpacing.xs) {
                Image(systemName: "mappin.and.ellipse")
                Text(selection.name)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: OceanSpacing.xs)
                Image(systemName: "chevron.up.chevron.down")
            }
            .font(OceanTypography.button)
            .foregroundStyle(OceanPalette.white)
            .padding(OceanSpacing.sm)
            .frame(minHeight: OceanGlass.minimumTapHeight)
        }
        .oceanGlassCapsule()
        .accessibilityLabel("Choisir un spot")
        .accessibilityValue(selection.name)
    }
}
