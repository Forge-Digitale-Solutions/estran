import SwiftUI
import WidgetKit

/// Shared iOS 27 ocean backdrop and concentric glass styling for widgets.
///
/// Mirrors `OceanBackdrop` and `GlassStyles` from the app target while
/// adapting to WidgetKit's `widgetRenderingMode` (`.fullColor`, `.accented`,
/// `.vibrant`), `accessibilityReduceTransparency`, and `colorSchemeContrast`.
struct WidgetOceanBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        Group {
            if renderingMode != .fullColor {
                Color.clear
            } else if reduceTransparency {
                OceanPalette.navyInk
            } else {
                mesh
            }
        }
        .accessibilityHidden(true)
    }

    private var mesh: some View {
        let glow = contrast == .increased ? 0.35 : 1.0
        return MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.52, 0.46], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ],
            colors: [
                OceanPalette.oceanDeepTop,
                OceanPalette.oceanDeepTop,
                OceanPalette.blueGlow.mix(with: OceanPalette.oceanDeepTop, by: 1 - 0.45 * glow),
                OceanPalette.turquoise.mix(with: OceanPalette.navyInk, by: 1 - 0.30 * glow),
                OceanPalette.navyInk,
                OceanPalette.oceanDeepTop,
                OceanPalette.oceanDeepBottom,
                OceanPalette.oceanDeepBottom,
                OceanPalette.blueGlow.mix(with: OceanPalette.oceanDeepBottom, by: 1 - 0.25 * glow)
            ],
            smoothsColors: true)
    }
}

/// Concentric glass sub-card for widget sections and metric tiles.
private struct WidgetGlassCardModifier: ViewModifier {
    let minimumRadius: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var shape: ConcentricRectangle {
        .rect(corners: .concentric(minimum: .fixed(minimumRadius)), isUniform: true)
    }

    private var fillStyle: Color {
        if renderingMode != .fullColor {
            return OceanPalette.white.opacity(0.1)
        }
        if reduceTransparency {
            return OceanPalette.navyInk
        }
        if contrast == .increased {
            return OceanPalette.navyInk.opacity(0.6)
        }
        return OceanPalette.white.opacity(0.1)
    }

    private var borderOpacity: Double {
        if contrast == .increased {
            return 0.5
        }
        if reduceTransparency {
            return 0.22
        }
        return 0.16
    }

    private var borderWidth: CGFloat {
        contrast == .increased ? 1.5 : 1.0
    }

    func body(content: Content) -> some View {
        content
            .background(fillStyle, in: shape)
            .overlay {
                shape.stroke(
                    OceanPalette.white.opacity(borderOpacity),
                    lineWidth: borderWidth)
            }
    }
}

extension View {
    /// Applies a concentric glass card background suited for widget sub-surfaces.
    func widgetGlassCard(minimumRadius: CGFloat = 10) -> some View {
        modifier(WidgetGlassCardModifier(minimumRadius: minimumRadius))
    }
}
