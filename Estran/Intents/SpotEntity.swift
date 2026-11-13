import AppIntents
import EstranCore
import Foundation
#if !ESTRAN_SDK_BEFORE_27
    import CoreSpotlight
#endif

/// One of the two gauged spots, as an App Intent entity indexed in Spotlight.
///
/// Identifiers match `SpotCatalog` so Siri, Shortcuts, the widgets and the app
/// never disagree on which place is meant. Only these two IDs exist (Invariant 8).
struct SpotEntity: AppEntity, IndexedEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Lieu")
    }

    static let defaultQuery = SpotEntityQuery()

    /// Stable catalog identifier (`pointe-de-grave`, `arcachon-eyrac`).
    var id: String

    init(id: String) {
        self.id = id
    }

    init(spot: Spot) {
        id = spot.id
    }

    /// The two shipped spots, ocean first.
    static var all: [SpotEntity] {
        SpotCatalog.v1.map(SpotEntity.init(spot:))
    }

    static let pointeDeGrave = SpotEntity(spot: SpotCatalog.pointeDeGrave)
    static let arcachonEyrac = SpotEntity(spot: SpotCatalog.arcachonEyrac)

    var spot: Spot {
        SpotCatalog.spot(id: id) ?? SpotCatalog.defaultSpot
    }

    @ComputedProperty(title: "Nom", indexingKey: \.displayName)
    var name: String {
        spot.name
    }

    @ComputedProperty(title: "Région", indexingKey: \.contentDescription)
    var regionDescription: String {
        FrenchFormat.regionName(spot.region)
    }

    @ComputedProperty(indexingKey: \.keywords)
    var keywords: [String] {
        [
            spot.name,
            FrenchFormat.regionName(spot.region),
            "marée",
            "estran",
            "océan",
            "bassin"
        ]
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(spot.name)",
            subtitle: "\(FrenchFormat.regionName(spot.region))",
            image: .init(systemName: "mappin.and.ellipse"),
            synonyms: synonyms)
    }

    private var synonyms: [LocalizedStringResource] {
        switch spot.id {
        case SpotCatalog.pointeDeGrave.id:
            ["Le Verdon", "Verdon-sur-Mer", "Port-Bloc", "Médoc"]
        case SpotCatalog.arcachonEyrac.id:
            ["Arcachon", "Eyrac", "Jetée d'Eyrac", "Bassin d'Arcachon"]
        default:
            []
        }
    }
}

/// Resolves, suggests and reindexes the two spots for Siri and Spotlight.
struct SpotEntityQuery: EntityStringQuery, EnumerableEntityQuery {
    func entities(for identifiers: [SpotEntity.ID]) async throws -> [SpotEntity] {
        identifiers.compactMap { id in
            guard SpotCatalog.spot(id: id) != nil else { return nil }
            return SpotEntity(id: id)
        }
    }

    func allEntities() async throws -> [SpotEntity] {
        SpotEntity.all
    }

    func entities(matching string: String) async throws -> [SpotEntity] {
        let needle = Self.folded(string)
        guard !needle.isEmpty else { return SpotEntity.all }
        return SpotEntity.all.filter { entity in
            let haystacks = [entity.name, entity.regionDescription] + entity.keywords
            return haystacks.contains { Self.folded($0).contains(needle) }
        }
    }

    private static func folded(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
    }
}

#if !ESTRAN_SDK_BEFORE_27
    extension SpotEntityQuery: IndexedEntityQuery {
        func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
            let index = Self.index(for: indexDescription)
            try await index.indexAppEntities(SpotEntity.all)
        }

        func reindexEntities(
            for identifiers: [SpotEntity.ID],
            indexDescription: CSSearchableIndexDescription) async throws
        {
            let entities = try await entities(for: identifiers)
            let index = Self.index(for: indexDescription)
            try await index.indexAppEntities(entities)
        }

        private static func index(for description: CSSearchableIndexDescription) -> CSSearchableIndex {
            CSSearchableIndex(name: "EstranSpots", protectionClass: description.protectionClass)
        }
    }
#endif
