import Foundation

/// The four tabs of the app (`DESIGN_REFERENCE.md` §3.1).
enum AppTab: Hashable, CaseIterable {
    case now
    case spots
    case alerts
    case settings

    var title: String {
        switch self {
        case .now: "Maintenant"
        case .spots: "Spots"
        case .alerts: "Alertes"
        case .settings: "Réglages"
        }
    }

    var symbolName: String {
        switch self {
        case .now: "sun.horizon"
        case .spots: "map"
        case .alerts: "bell"
        case .settings: "gearshape"
        }
    }
}
