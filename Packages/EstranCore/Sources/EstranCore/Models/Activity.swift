import Foundation

/// The five activities supported by Estran.
public enum Activity: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case shoreFishing
    case surfing
    case boating
    case walking
    case swimming

    public var id: String {
        rawValue
    }

    /// Short French label shown in the UI.
    public var displayName: String {
        switch self {
        case .shoreFishing:
            "Pêche à pied"
        case .surfing:
            "Surf"
        case .boating:
            "Bateau"
        case .walking:
            "Balade"
        case .swimming:
            "Baignade"
        }
    }

    /// Short French label used by the Home segmented control.
    ///
    /// « Bain » is the agreed short form of « Baignade » in the segmented
    /// control (`DESIGN_REFERENCE.md` §5); the full label is always used in
    /// sentences and accessibility labels.
    public var shortLabel: String {
        switch self {
        case .shoreFishing:
            "Pêche"
        case .surfing:
            "Surf"
        case .boating:
            "Bateau"
        case .walking:
            "Balade"
        case .swimming:
            "Bain"
        }
    }

    /// French label with its definite article, for sentences.
    public var displayNameWithArticle: String {
        switch self {
        case .shoreFishing:
            "la pêche à pied"
        case .surfing:
            "le surf"
        case .boating:
            "le bateau"
        case .walking:
            "la balade"
        case .swimming:
            "la baignade"
        }
    }

    /// SF Symbol used by the UI and widgets.
    public var symbolName: String {
        switch self {
        case .shoreFishing:
            "fish"
        case .surfing:
            "figure.surfing"
        case .boating:
            "sailboat"
        case .walking:
            "figure.walk"
        case .swimming:
            "figure.pool.swim"
        }
    }
}
