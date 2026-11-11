import EstranCore
import SwiftUI

/// Ocean palette confirmed from the Figma file `v3 kit iOS 27`.
enum OceanPalette {
    static let oceanDeepTop = Color(hex: 0x0A3D62)
    static let oceanDeepBottom = Color(hex: 0x031426)
    static let navyInk = Color(hex: 0x06223F)
    static let turquoise = Color(hex: 0x30D5C8)
    static let blueGlow = Color(hex: 0x0091FF)
    static let sand = Color(hex: 0xF2E3C2)
    static let white = Color(hex: 0xFFFFFF)
    static let oui = Color(hex: 0x34C759)
    static let ouiDark = Color(hex: 0x03210F)
    static let non = Color(hex: 0xFF6B5B)
    static let glassTint = Color(hex: 0xBFD9FF)
    static let segmentedBackground = Color(hex: 0x767680)
    static let chartHighlight = Color(hex: 0x30D158)
    /// Neutral colour for the « Données indisponibles » state.
    ///
    /// It is deliberately neither green nor coral: an unavailable verdict is not
    /// a refusal, and the colour is always paired with an icon and a word.
    static let unavailable = Color(hex: 0xF2E3C2)
    /// Text on the selected segment (white pill).
    static let ink = Color(hex: 0x06223F)
    /// Small text variants of the two accent hues, for glass and gradient
    /// backgrounds only (see `swimmingRiskText(_:)`).
    static let turquoiseOnGlass = Color(hex: 0x5DDED4)
    static let nonOnGlass = Color(hex: 0xFFBAB2)
    /// Green as 11–17 pt text on glass: `oui` measures 3.30:1 there, this
    /// 4.67:1 at the audit's 15 % model and 6.22:1 on the sampled card.
    static let ouiOnGlass = Color(hex: 0x7BE495)
    /// Permanent navy scrim laid behind glass cards over map tiles (`SpotsView`),
    /// where the raster backdrop is brighter than the ocean gradient
    /// (`docs/accessibility/settings-pass-2026-11-11.md` §6 B1/B2).
    static let mapGlassScrimOpacity: Double = 0.45

    /// Colour for a swimming risk level. Never `oui`: swimming has no green.
    static func swimmingRisk(_ level: SwimmingRiskLevel) -> Color {
        switch level {
        case .low: turquoise
        case .moderate: sand
        case .strong: non
        case .unknown: unavailable
        }
    }

    /// Same scale for **text drawn on glass or on the background gradient**.
    ///
    /// `non` (#FF6B5B) and `turquoise` (#30D5C8) are the Figma hues and stay
    /// right for large display and for glyphs on the opaque Live Activity
    /// background. As 11–17 pt text on a translucent card they fall under
    /// 4.5:1 (`docs/accessibility/contrast-audit.md`, A20/B21/B23/B50). These
    /// two values are the same hue lifted to clear 4.5:1 at the audit's darkest
    /// modelled glass (15 % white) and keep headroom on the measured render.
    static func swimmingRiskText(_ level: SwimmingRiskLevel) -> Color {
        switch level {
        case .low: turquoiseOnGlass
        case .moderate: sand
        case .strong: nonOnGlass
        case .unknown: unavailable
        }
    }

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [oceanDeepTop, oceanDeepBottom],
            startPoint: .top,
            endPoint: .bottom)
    }
}

private extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
