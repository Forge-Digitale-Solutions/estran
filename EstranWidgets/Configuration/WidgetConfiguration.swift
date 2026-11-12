import AppIntents
import EstranCore
import Foundation

/// The spot a widget can be configured to, including « Automatique » (follow
/// the app). Identifiers mirror `SpotCatalog` so the widget, the app and Siri
/// never disagree on which place is meant.
enum WidgetSpot: String, AppEnum, CaseIterable {
    case automatic
    case pointeDeGrave
    case arcachonEyrac

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Lieu"
    }

    static var caseDisplayRepresentations: [WidgetSpot: DisplayRepresentation] {
        [
            .automatic: "Automatique",
            .pointeDeGrave: "Pointe de Grave",
            .arcachonEyrac: "Arcachon-Eyrac"
        ]
    }

    /// The catalog identifier, or `nil` for « Automatique ».
    var spotID: String? {
        switch self {
        case .automatic: nil
        case .pointeDeGrave: SpotCatalog.pointeDeGrave.id
        case .arcachonEyrac: SpotCatalog.arcachonEyrac.id
        }
    }

    /// The concrete spot, following the app's selection for « Automatique ».
    func resolvedSpot(selectedID: String?) -> Spot {
        WidgetSelection.spot(configuredID: spotID, selectedID: selectedID)
    }
}

/// The activity a widget can be configured to, including « Automatique ».
enum WidgetActivity: String, AppEnum, CaseIterable {
    case automatic
    case shoreFishing
    case surfing
    case boating
    case walking
    case swimming

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Activité"
    }

    static var caseDisplayRepresentations: [WidgetActivity: DisplayRepresentation] {
        [
            .automatic: "Automatique",
            .shoreFishing: "Pêche à pied",
            .surfing: "Surf",
            .boating: "Bateau",
            .walking: "Balade",
            .swimming: "Baignade"
        ]
    }

    /// The concrete activity, or `nil` for « Automatique ».
    var activity: Activity? {
        switch self {
        case .automatic: nil
        case .shoreFishing: .shoreFishing
        case .surfing: .surfing
        case .boating: .boating
        case .walking: .walking
        case .swimming: .swimming
        }
    }

    init(activity: Activity) {
        switch activity {
        case .shoreFishing: self = .shoreFishing
        case .surfing: self = .surfing
        case .boating: self = .boating
        case .walking: self = .walking
        case .swimming: self = .swimming
        }
    }
}

/// The Go widget's configuration: a spot and an activity.
struct ConfigureGoWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource {
        "Estran"
    }

    static var description: IntentDescription {
        IntentDescription("Le verdict ou le niveau de risque, en un coup d'œil.")
    }

    @Parameter(title: "Lieu", default: .automatic)
    var spot: WidgetSpot

    @Parameter(
        title: "Activité",
        default: .automatic,
        optionsProvider: WidgetActivityOptionsProvider())
    var activity: WidgetActivity
}

/// The Conditions widget's configuration: a spot only.
struct ConfigureConditionsWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource {
        "Conditions"
    }

    static var description: IntentDescription {
        IntentDescription("Marée, vent, houle et météo du lieu choisi.")
    }

    @Parameter(title: "Lieu", default: .automatic)
    var spot: WidgetSpot
}

/// Offers only the activities the chosen spot actually has (no surf at Eyrac),
/// plus « Automatique ». Reads the spot the user is configuring through the
/// parameter dependency, so the two controls stay in sync.
struct WidgetActivityOptionsProvider: DynamicOptionsProvider {
    @IntentParameterDependency<ConfigureGoWidgetIntent>(\.$spot)
    var dependency

    func results() async throws -> [WidgetActivity] {
        guard let spot = dependency?.spot else {
            return WidgetActivity.allCases
        }
        let offered = Set(WidgetSelection.offeredActivities(at: spot.resolvedSpot(selectedID: nil)))
        return WidgetActivity.allCases.filter { widgetActivity in
            guard let activity = widgetActivity.activity else { return true }
            return offered.contains(activity)
        }
    }

    func defaultResult() async -> WidgetActivity? {
        .automatic
    }
}
