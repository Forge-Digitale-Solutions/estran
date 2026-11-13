import SwiftUI

/// Adaptive geometry shared by every screen.
///
/// Estran targets iPhone, but it also has to fill the iPhone Duo's unfolded
/// display (2853 × 2007 px ≈ 951 × 669 pt) instead of the letterboxed column a
/// portrait-only window produced. The layout therefore asks two questions about
/// the **window**, never about the device:
///
/// 1. how wide is the content area (read from the `GeometryReader` that wraps
///    each screen), and
/// 2. which `horizontalSizeClass` does the system report.
///
/// A classic iPhone in portrait (~440 pt) stays single-column. The Duo folded
/// (~466 pt) does too, so the cover display is the phone layout the design was
/// drawn for. The Duo unfolded (~951 pt) and a landscape iPhone at regular width
/// get two columns, because the extra width is the only thing that changed.
///
/// **Dynamic Type wins over width.** AX5 is a release gate and
/// `DESIGN_REFERENCE.md` §2.1 is explicit: at accessibility sizes horizontal
/// pairs become stacks and the grid becomes one column. A two-column split at
/// AX5 would hand each column less room than the phone layout it is supposed to
/// improve, so `usesTwoColumns` returns `false` there and the single column is
/// capped at `readableContentWidth` instead.
enum OceanLayout {
    /// Width at which a second column earns its place, in points.
    static let wideBreakpoint: CGFloat = 700

    /// Ceiling for one column of text. A 951 pt line runs ~120 characters;
    /// 760 pt keeps a comfortable measure on the widest display.
    static let readableContentWidth: CGFloat = 760

    /// The side column of the two-column layouts (conditions on Home, the spot
    /// card on the map, the activity list on the spot detail).
    static let sideColumnIdealWidth: CGFloat = 340
    static let sideColumnMinimumWidth: CGFloat = 300
    static let sideColumnMaximumWidth: CGFloat = 380

    /// Gap between the two columns. Same as `OceanSpacing.lg`.
    static let columnSpacing: CGFloat = 24

    /// Whether the window is wide enough for the two-column shape.
    ///
    /// `width` comes from the screen's `GeometryReader`. The size class is only
    /// the fallback for the first layout pass and for render tests, where a view
    /// can be asked to lay out at a regular size class before it has measured
    /// anything (`ImageRenderer` has no window).
    static func usesTwoColumns(
        width: CGFloat,
        sizeClass: UserInterfaceSizeClass?,
        dynamicTypeSize: DynamicTypeSize) -> Bool
    {
        guard !dynamicTypeSize.isAccessibilitySize else { return false }
        if width > 0 {
            return width >= wideBreakpoint
        }
        return sizeClass == .regular
    }
}

extension View {
    /// Caps the content at a readable measure and centres it on a display wider
    /// than a phone. On a phone-width window it is the identity.
    func oceanReadableWidth(_ maximum: CGFloat = OceanLayout.readableContentWidth) -> some View {
        frame(maxWidth: maximum, alignment: .leading)
            .frame(maxWidth: .infinity)
    }
}
