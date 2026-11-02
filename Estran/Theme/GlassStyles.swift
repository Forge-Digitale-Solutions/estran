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
    /// Minimum tappable height (HIG: 44 × 44 pt).
    static let minimumTapHeight: CGFloat = 44

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

    init(reduceTransparency: Bool, increaseContrast: Bool) {
        // The fill and the backing are exclusive: an opaque card has nothing
        // left to darken, and glass under a full backing is no longer glass.
        usesSolidFill = reduceTransparency
        backingOpacity = (increaseContrast && !reduceTransparency)
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

private struct OceanGlassSurfaceModifier<Surface: InsettableShape>: ViewModifier {
    let shape: Surface

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var appearance: GlassAppearance {
        GlassAppearance(
            reduceTransparency: reduceTransparency,
            increaseContrast: colorSchemeContrast == .increased)
    }

    func body(content: Content) -> some View {
        let state = appearance
        Group {
            if state.usesSolidFill {
                content
                    .background(OceanPalette.navyInk, in: shape)
            } else if state.backingOpacity > 0 {
                content
                    .background(OceanPalette.navyInk.opacity(state.backingOpacity), in: shape)
                    .glassEffect(.regular, in: shape)
            } else {
                content
                    .glassEffect(.regular, in: shape)
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

extension View {
    func oceanGlassCard(cornerRadius: CGFloat = OceanGlass.cardCornerRadius) -> some View {
        modifier(
            OceanGlassSurfaceModifier(
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
    }

    func oceanGlassCapsule() -> some View {
        modifier(OceanGlassSurfaceModifier(shape: Capsule(style: .continuous)))
    }
}
