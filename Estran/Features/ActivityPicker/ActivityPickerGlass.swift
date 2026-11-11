import SwiftUI

// Glass and motion helpers for the activity picker sheet.
//
// They live beside `ActivityPickerView` rather than inside it because that file
// already sits at the SwiftLint `file_length` ceiling, and because the two
// concerns are self-contained: one draws the bar-button surface, the other
// stages the entrance of the activity rows.

// MARK: - Bar button glass

/// The circular close / confirm buttons: interactive Liquid Glass with the two
/// accessibility looks of `GlassStyles.swift`.
///
/// They used to call `.glassEffect(.regular, in: Circle())` directly, which is
/// why under Reduce Transparency they rendered as a near-black system glass
/// while the rows behind them were solid `navyInk` (accessibility report §5.1).
/// `oceanGlassCapsule()` / `oceanGlassChip()` cannot be used here — they only
/// build a capsule — so the three states are reproduced for a circle. A
/// `oceanGlassCircle()` in `GlassStyles.swift` would let this type go away.
///
/// - **Reduce Transparency** — opaque `navyInk` fill, no glass, 1 pt white 0.18
///   border (1.5 pt white 0.5 with Increase Contrast).
/// - **Increase Contrast** — glass over a 45 % `navyInk` backing plus the 1.5 pt
///   white 0.5 border.
/// - **Default** — `.regular.interactive()`, no border: the shipped look.
///
/// Reduce Motion is not a look: `.interactive()` only deflects under the finger
/// and never travels, so it stays on in every configuration.
struct PickerBarGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func body(content: Content) -> some View {
        let state = GlassAppearance(
            reduceTransparency: reduceTransparency,
            increaseContrast: colorSchemeContrast == .increased)
        let shape = Circle()
        return Group {
            if state.usesSolidFill {
                content
                    .background(OceanPalette.navyInk, in: shape)
            } else if state.backingOpacity > 0 {
                content
                    .background(OceanPalette.navyInk.opacity(state.backingOpacity), in: shape)
                    .glassEffect(.regular.interactive(), in: shape)
            } else {
                content
                    .glassEffect(.regular.interactive(), in: shape)
            }
        }
        .overlay {
            if state.drawsBorder {
                shape.strokeBorder(
                    OceanPalette.white.opacity(state.borderOpacity),
                    lineWidth: state.borderWidth)
            }
        }
    }
}

// MARK: - Row entrance

/// Staggered entrance for the activity rows: each one rises 10 pt and fades in
/// 50 ms after the row above, so the sheet assembles instead of appearing whole.
///
/// Under Reduce Motion the modifier draws nothing: the rows are at full opacity
/// in their final position, on the first frame.
struct PickerTileEntrance: ViewModifier {
    /// Rank in the list; the delay is a function of it.
    let index: Int
    /// Flips once, on appear.
    let appeared: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(
                    OceanGlass.animation(
                        .spring(response: 0.42, dampingFraction: 0.86)
                            .delay(0.05 * Double(index)),
                        reduceMotion: reduceMotion),
                    value: appeared)
        }
    }
}
