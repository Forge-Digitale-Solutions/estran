import SwiftUI

/// Shared Liquid Glass surface styling.
///
/// **iOS 27 glass, not a pre-26 material.** Every surface uses
/// `glassEffect(_:in:)`, which provides the refraction, specular edge and shape
/// merging the system uses. `.ultraThinMaterial` is deliberately absent: it is
/// the pre-iOS 26 look and the one detail that makes a showcase app feel
/// foreign on its own OS (`ARCHITECTURE_PLAN.md` §12.3).
///
/// Radii follow `DESIGN_REFERENCE.md` §6: answer card 34, cards 26, tiles 22.
///
/// ## Accessibility states
///
/// A surface reads two environment flags and picks one of four looks. The
/// decision lives in `GlassAppearance` (tested); this file only draws it.
///
/// - **Reduce Transparency off, Increase Contrast off** — Liquid Glass, no
///   border: the shipped Figma look, unchanged.
/// - **Reduce Transparency on, Increase Contrast off** — the glass is replaced
///   by an opaque `navyInk` (`#06223F`) fill with the same corner radius, plus
///   a 1 pt white 0.18 border. Text keeps its contrast on the solid card.
/// - **Increase Contrast on, Reduce Transparency off** — the glass stays, laid
///   over a 45 % `navyInk` backing so the light text gains contrast, plus a
///   1.5 pt white 0.5 border. Text and glyphs keep the existing `*OnGlass`
///   tokens (`swimmingRiskText(_:)`, `ouiOnGlass`, `nonOnGlass`,
///   `turquoiseOnGlass`); no new colour is introduced.
/// - **Both on** — opaque `navyInk` fill with the increase-contrast border
///   (1.5 pt white 0.5): the fill already gives the contrast, so the backing is
///   not drawn and the stronger border wins.
///
/// Reduce Motion is not a look: it removes animation. Surfaces call
/// `OceanGlass.animation(_:reduceMotion:)` with the value of
/// `\.accessibilityReduceMotion`, and pass `nil` to `withAnimation` when motion
/// is off. No animation call site is changed from here.
enum OceanGlass {
    static let answerCornerRadius: CGFloat = 34
    static let cardCornerRadius: CGFloat = 26
    static let tileCornerRadius: CGFloat = 22
    static let capsuleRadius: CGFloat = 24
    /// Default minimum corner radius for concentric inner shapes nested inside a
    /// glass card, so deep padding never collapses an inner corner to a sharp square.
    static let innerCornerMinimum: CGFloat = 10
    /// Minimum tappable height (HIG: 44 × 44 pt).
    static let minimumTapHeight: CGFloat = 44

    /// Uniform concentric rectangle aligned with the enclosing `.containerShape(...)`.
    static func concentricShape(
        minimumRadius: CGFloat = innerCornerMinimum) -> ConcentricRectangle
    {
        .rect(corners: .concentric(minimum: .fixed(minimumRadius)), isUniform: true)
    }

    /// Animation to use for a surface, or `nil` when Reduce Motion is on.
    ///
    /// The flag is a per-view `@Environment` value, so the caller reads it and
    /// passes it in:
    ///
    /// ```swift
    /// @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// …
    /// withAnimation(OceanGlass.animation(.spring(response: 0.45), reduceMotion: reduceMotion)) {
    ///     // change
    /// }
    /// ```
    ///
    /// `withAnimation(nil)` applies the change without animating, which is the
    /// behaviour Reduce Motion asks for. The helper is pure and independent of
    /// the actor it is called from, so it is testable directly.
    static func animation(_ animation: Animation?, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}

/// The look a glass surface takes for the two accessibility flags.
///
/// Kept as a plain value so the decisions are testable without rendering
/// `glassEffect`, which the simulator cannot inspect.
struct GlassAppearance: Equatable, Sendable {
    /// Opaque card border: 1 pt white at 18 % (`accessibilityReduceTransparency`).
    static let solidBorderWidth: CGFloat = 1
    static let solidBorderOpacity: Double = 0.18
    /// Increase Contrast border: 1.5 pt white at 50 %.
    static let contrastBorderWidth: CGFloat = 1.5
    static let contrastBorderOpacity: Double = 0.5
    /// Navy laid behind the glass in Increase Contrast so light text gains
    /// contrast without changing any hue.
    static let contrastBackingOpacity: Double = 0.45

    /// `true` replaces the glass with an opaque `navyInk` fill.
    let usesSolidFill: Bool
    /// White border width in points; `0` draws no border.
    let borderWidth: CGFloat
    /// White border opacity; `0` when `borderWidth` is `0`.
    let borderOpacity: Double
    /// `navyInk` backing opacity under the glass; `0` when nothing is drawn.
    let backingOpacity: Double

    init(
        reduceTransparency: Bool,
        increaseContrast: Bool,
        permanentBacking: Bool = false)
    {
        // The fill and the backing are exclusive: an opaque card has nothing
        // left to darken, and glass under a full backing is no longer glass.
        usesSolidFill = reduceTransparency
        backingOpacity = ((increaseContrast || permanentBacking) && !reduceTransparency)
            ? Self.contrastBackingOpacity
            : 0
        if reduceTransparency {
            // Increase Contrast is additive: keep the stronger border on the
            // opaque card rather than dropping the user's preference.
            borderWidth = increaseContrast
                ? Self.contrastBorderWidth
                : Self.solidBorderWidth
            borderOpacity = increaseContrast
                ? Self.contrastBorderOpacity
                : Self.solidBorderOpacity
        } else {
            borderWidth = increaseContrast ? Self.contrastBorderWidth : 0
            borderOpacity = increaseContrast ? Self.contrastBorderOpacity : 0
        }
    }

    /// Whether a border is drawn at all.
    var drawsBorder: Bool {
        borderWidth > 0
    }
}

private struct OceanGlassSurfaceModifier<Surface: Shape>: ViewModifier {
    let shape: Surface
    let permanentBacking: Bool
    let tint: Color?
    let isInteractive: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var appearance: GlassAppearance {
        GlassAppearance(
            reduceTransparency: reduceTransparency,
            increaseContrast: colorSchemeContrast == .increased,
            permanentBacking: permanentBacking)
    }

    private var resolvedGlass: Glass {
        let base: Glass = if let tint {
            Glass.regular.tint(tint)
        } else {
            .regular
        }
        return isInteractive ? base.interactive() : base
    }

    func body(content: Content) -> some View {
        let state = appearance
        let glass = resolvedGlass
        Group {
            if state.usesSolidFill {
                content
                    .background(tint ?? OceanPalette.navyInk, in: shape)
            } else if state.backingOpacity > 0, tint == nil {
                content
                    .background(OceanPalette.navyInk.opacity(state.backingOpacity), in: shape)
                    .glassEffect(glass, in: shape)
            } else {
                content
                    .glassEffect(glass, in: shape)
            }
        }
        .overlay {
            if state.drawsBorder {
                shape.stroke(
                    OceanPalette.white.opacity(state.borderOpacity),
                    lineWidth: state.borderWidth)
            }
        }
    }
}

/// Nested concentric well or callout row inside an `oceanGlassCard` surface.
///
/// Uses `ConcentricRectangle` so its corners match the enclosing card's
/// `containerShape` minus padding, and routes through `GlassAppearance` so
/// Reduce Transparency (opaque `navyInk` + 1 pt border) and Increase Contrast
/// (45 % `navyInk` backing + 1.5 pt border) draw the border along the same
/// concentric shape.
private struct OceanConcentricInsetModifier: ViewModifier {
    let minimumRadius: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private static let defaultBackingOpacity: Double = 0.26
    private static let defaultBorderOpacity: Double = 0.12

    private var shape: ConcentricRectangle {
        OceanGlass.concentricShape(minimumRadius: minimumRadius)
    }

    private var appearance: GlassAppearance {
        GlassAppearance(
            reduceTransparency: reduceTransparency,
            increaseContrast: colorSchemeContrast == .increased)
    }

    private var fillStyle: Color {
        let state = appearance
        if state.usesSolidFill {
            return OceanPalette.navyInk
        }
        if state.backingOpacity > 0 {
            return OceanPalette.navyInk.opacity(state.backingOpacity)
        }
        return OceanPalette.navyInk.opacity(Self.defaultBackingOpacity)
    }

    private var borderWidth: CGFloat {
        let state = appearance
        return state.drawsBorder ? state.borderWidth : 1
    }

    private var borderOpacity: Double {
        let state = appearance
        return state.drawsBorder ? state.borderOpacity : Self.defaultBorderOpacity
    }

    func body(content: Content) -> some View {
        let concentric = shape
        content
            .background(fillStyle, in: concentric)
            .overlay {
                concentric.stroke(
                    OceanPalette.white.opacity(borderOpacity),
                    lineWidth: borderWidth)
            }
    }
}

extension View {
    func oceanGlassCard(
        cornerRadius: CGFloat = OceanGlass.cardCornerRadius,
        permanentBacking: Bool = false) -> some View
    {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return containerShape(shape)
            .modifier(
                OceanGlassSurfaceModifier(
                    shape: shape,
                    permanentBacking: permanentBacking,
                    tint: nil,
                    isInteractive: false))
    }

    /// Liquid Glass surface whose corners are concentric with an enclosing
    /// `containerShape`, keeping all four `GlassAppearance` accessibility states.
    func oceanGlassConcentricCard(
        minimumRadius: CGFloat = OceanGlass.innerCornerMinimum,
        permanentBacking: Bool = false) -> some View
    {
        modifier(
            OceanGlassSurfaceModifier(
                shape: OceanGlass.concentricShape(minimumRadius: minimumRadius),
                permanentBacking: permanentBacking,
                tint: nil,
                isInteractive: false))
    }

    /// Nested concentric well, row or callout inside an `oceanGlassCard`.
    func oceanConcentricInset(
        minimumRadius: CGFloat = OceanGlass.innerCornerMinimum) -> some View
    {
        modifier(OceanConcentricInsetModifier(minimumRadius: minimumRadius))
    }

    func oceanGlassCapsule(
        tinting tint: Color? = nil,
        interactive isInteractive: Bool = false) -> some View
    {
        let shape = Capsule(style: .continuous)
        return containerShape(shape)
            .modifier(
                OceanGlassSurfaceModifier(
                    shape: shape,
                    permanentBacking: false,
                    tint: tint,
                    isInteractive: isInteractive))
    }

    /// Shared Liquid Glass capsule styling for interactive segmented chips
    /// (`SpotSwitcher`, `ActivitySegmentedControl`). Routes both selected
    /// (white-tinted) and unselected chips through `GlassAppearance` so Reduce
    /// Transparency (`navyInk` / `white` solid fill) and Increase Contrast
    /// (45 % `navyInk` backing + 1.5 pt border) reach them (`settings-pass` §5.1).
    func oceanGlassChip(
        isSelected: Bool,
        isInteractive: Bool = true) -> some View
    {
        oceanGlassCapsule(
            tinting: isSelected ? OceanPalette.white : nil,
            interactive: isInteractive)
    }

    /// Circular Liquid Glass surface for an icon-only control — the picker's
    /// close and confirm buttons (`ActivityPickerView`).
    ///
    /// Same four looks as `oceanGlassCard`, because it is the same modifier:
    /// Liquid Glass, the opaque `navyInk` fill under Reduce Transparency, the
    /// 45 % backing plus 1.5 pt border under Increase Contrast, and both
    /// together. `interactive` keeps the specular deflection under the finger;
    /// the surface only deflects and never travels, so Reduce Motion leaves it
    /// on in every configuration.
    func oceanGlassCircle(interactive isInteractive: Bool = false) -> some View {
        let shape = Circle()
        return containerShape(shape)
            .modifier(
                OceanGlassSurfaceModifier(
                    shape: shape,
                    permanentBacking: false,
                    tint: nil,
                    isInteractive: isInteractive))
    }
}
