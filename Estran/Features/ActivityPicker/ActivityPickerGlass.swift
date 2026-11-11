import SwiftUI

// Motion helper for the activity picker sheet.
//
// The bar-button glass used to live here. It now uses the shared
// `oceanGlassCircle(interactive:)` in `Theme/GlassStyles.swift`, so the close and
// confirm buttons take the same Reduce Transparency / Increase Contrast looks as
// every card. What remains is the row entrance, kept out of
// `ActivityPickerView.swift` because that file already sits at the SwiftLint
// `file_length` ceiling.

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
