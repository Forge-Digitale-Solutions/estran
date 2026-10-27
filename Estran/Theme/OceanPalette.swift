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

    /// Colour for a swimming risk level. Never `oui`: swimming has no green.
    static func swimmingRisk(_ level: SwimmingRiskLevel) -> Color {
        switch level {
        case .low: turquoise
        case .moderate: sand
        case .strong: non
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
