#if canImport(SwiftData)
    @testable import EstranCore
    import SwiftData
    import XCTest

    final class ModelContainerTests: XCTestCase {
        @MainActor
        func testInMemoryContainerStoresFavoriteSpot() throws {
            let container = try EstranModelContainer.make(inMemory: true)
            let context = container.mainContext

            context.insert(FavoriteSpot(spotID: "cap-ferret"))
            try context.save()

            let favorites = try context.fetch(FetchDescriptor<FavoriteSpot>())
            XCTAssertEqual(favorites.map(\.spotID), ["cap-ferret"])
        }
    }
#endif
