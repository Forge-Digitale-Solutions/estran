import AppIntents
import EstranCore
import Foundation
#if !ESTRAN_SDK_BEFORE_27
    import CoreSpotlight
#endif

/// One of the five activities, as an App Intent entity indexed in Spotlight.
///
/// Searching « surf » or « baignade » surfaces the matching entity. Opening it
/// launches Estran; applying the activity in `AppModel` still needs an app-side
/// hook outside this intents folder.
struct ActivityEntity: AppEntity, IndexedEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Activité")
    }

    static let defaultQuery = ActivityEntityQuery()

    /// Stable `Activity.rawValue`.
    var id: String

    init(id: String) {
        self.id = id
    }

    init(activity: Activity) {
        id = activity.rawValue
    }

    static var all: [ActivityEntity] {
        Activity.allCases.map(ActivityEntity.init(activity:))
    }

    static let shoreFishing = ActivityEntity(activity: .shoreFishing)
    static let surfing = ActivityEntity(activity: .surfing)
    static let boating = ActivityEntity(activity: .boating)
    static let walking = ActivityEntity(activity: .walking)
    static let swimming = ActivityEntity(activity: .swimming)

    var activity: Activity {
        Activity(rawValue: id) ?? .shoreFishing
    }

    @ComputedProperty(title: "Nom", indexingKey: \.displayName)
    var name: String {
        activity.displayName
    }

    @ComputedProperty(indexingKey: \.keywords)
    var keywords: [String] {
        var words = [activity.displayName, activity.shortLabel, activity.rawValue]
        switch activity {
        case .shoreFishing:
            words += ["pêche", "pêcher", "estran"]
        case .surfing:
            words += ["surf", "surfer", "vague"]
        case .boating:
            words += ["bateau", "naviguer", "voile"]
        case .walking:
            words += ["balade", "marche", "promenade"]
        case .swimming:
            words += ["baignade", "nager", "bain", "baïnes"]
        }
        return words
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(activity.displayName)",
            subtitle: "Estran",
            image: .init(systemName: activity.symbolName),
            synonyms: synonyms)
    }

    private var synonyms: [LocalizedStringResource] {
        switch activity {
        case .shoreFishing: ["Pêche", "Pêcher à pied"]
        case .surfing: ["Surfer", "Vague"]
        case .boating: ["Navigation", "Voile"]
        case .walking: ["Marche", "Promenade"]
        case .swimming: ["Bain", "Nager"]
        }
    }
}

/// Resolves, suggests and reindexes the five activities for Siri and Spotlight.
#if ESTRAN_SDK_BEFORE_27
struct ActivityEntityQuery: EntityStringQuery, EnumerableEntityQuery {
#else
struct ActivityEntityQuery: EntityStringQuery, EnumerableEntityQuery, IndexedEntityQuery {
#endif
    func entities(for identifiers: [ActivityEntity.ID]) async throws -> [ActivityEntity] {
        identifiers.compactMap { id in
            guard Activity(rawValue: id) != nil else { return nil }
            return ActivityEntity(id: id)
        }
    }

    func allEntities() async throws -> [ActivityEntity] {
        ActivityEntity.all
    }

    func entities(matching string: String) async throws -> [ActivityEntity] {
        let needle = Self.folded(string)
        guard !needle.isEmpty else { return ActivityEntity.all }
        return ActivityEntity.all.filter { entity in
            let haystacks = [entity.name] + entity.keywords
            return haystacks.contains { Self.folded($0).contains(needle) }
        }
    }

    #if !ESTRAN_SDK_BEFORE_27
        func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
            let index = Self.index(for: indexDescription)
            try await index.indexAppEntities(ActivityEntity.all)
        }

        func reindexEntities(
            for identifiers: [ActivityEntity.ID],
            indexDescription: CSSearchableIndexDescription) async throws
        {
            let entities = try await entities(for: identifiers)
            let index = Self.index(for: indexDescription)
            try await index.indexAppEntities(entities)
        }

        private static func index(for description: CSSearchableIndexDescription) -> CSSearchableIndex {
            CSSearchableIndex(name: "EstranActivities", protectionClass: description.protectionClass)
        }
    #endif

    private static func folded(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
    }
}
