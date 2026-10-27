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
enum OceanGlass {
    static let answerCornerRadius: CGFloat = 34
    static let cardCornerRadius: CGFloat = 26
    static let tileCornerRadius: CGFloat = 22
    static let capsuleRadius: CGFloat = 24
    /// Minimum tappable height (HIG: 44 × 44 pt).
    static let minimumTapHeight: CGFloat = 44
}

private struct OceanGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.glassEffect(
            .regular,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct OceanGlassCapsuleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.glassEffect(.regular, in: Capsule(style: .continuous))
    }
}

extension View {
    func oceanGlassCard(cornerRadius: CGFloat = OceanGlass.cardCornerRadius) -> some View {
        modifier(OceanGlassCardModifier(cornerRadius: cornerRadius))
    }

    func oceanGlassCapsule() -> some View {
        modifier(OceanGlassCapsuleModifier())
    }
}
