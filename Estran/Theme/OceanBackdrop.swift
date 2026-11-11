import SwiftUI

/// Living ocean background behind every Liquid Glass surface.
///
/// Glass only refracts what is behind it: over the flat two-stop gradient it
/// reads as a grey card. A slow 3 × 3 `MeshGradient` gives the refraction
/// something to bend — a deep navy field with a turquoise and a blue glow that
/// drift like light under water (`docs/design/ios27-opportunities.md`, item 2).
///
/// ## Accessibility
///
/// - **Reduce Motion** — the mesh is drawn once at rest; no `TimelineView`
///   runs, so nothing moves and nothing redraws.
/// - **Increase Contrast** — the glows are dimmed so light text on glass keeps
///   its margin; the field stays the same navy.
/// - The backdrop is decorative: hidden from VoiceOver.
///
/// The edge points never move, so the safe-area edges stay the palette's
/// `oceanDeepTop` / `oceanDeepBottom` and the status bar keeps its contrast.
struct OceanBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if reduceMotion || scenePhase != .active {
                mesh(at: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    mesh(at: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func mesh(at time: TimeInterval) -> some View {
        let drift = Float(sin(time / 7)) * 0.08
        let sway = Float(cos(time / 9)) * 0.06
        let glow = contrast == .increased ? 0.35 : 1.0
        return MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.5 + drift, 0.45 + sway], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ],
            colors: [
                OceanPalette.oceanDeepTop, OceanPalette.oceanDeepTop,
                OceanPalette.blueGlow.mix(with: OceanPalette.oceanDeepTop, by: 1 - 0.45 * glow),
                OceanPalette.turquoise.mix(with: OceanPalette.navyInk, by: 1 - 0.30 * glow),
                OceanPalette.navyInk,
                OceanPalette.oceanDeepTop,
                OceanPalette.oceanDeepBottom, OceanPalette.oceanDeepBottom,
                OceanPalette.blueGlow.mix(with: OceanPalette.oceanDeepBottom, by: 1 - 0.25 * glow)
            ],
            smoothsColors: true)
    }
}

#Preview {
    OceanBackdrop()
}
