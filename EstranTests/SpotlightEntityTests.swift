@testable import Estran
import EstranCore
import XCTest

/// Spotlight entity queries: string match for « Pointe de Grave » / « surf ».
final class SpotlightEntityTests: XCTestCase {
    func testSpotQueryMatchesPointeDeGrave() async throws {
        let matches = try await SpotEntityQuery().entities(matching: "Pointe de Grave")

        XCTAssertEqual(matches.map(\.id), [SpotCatalog.pointeDeGrave.id])
    }

    func testSpotQueryMatchesArcachonSynonym() async throws {
        let matches = try await SpotEntityQuery().entities(matching: "Eyrac")

        XCTAssertTrue(matches.contains { $0.id == SpotCatalog.arcachonEyrac.id })
    }

    func testSpotQueryAllEntitiesAreTheTwoSpots() async throws {
        let all = try await SpotEntityQuery().allEntities()

        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(Set(all.map(\.id)), Set(SpotCatalog.v1.map(\.id)))
    }

    func testActivityQueryMatchesSurf() async throws {
        let matches = try await ActivityEntityQuery().entities(matching: "surf")

        XCTAssertTrue(matches.contains { $0.activity == .surfing })
    }

    func testActivityQueryMatchesBaignade() async throws {
        let matches = try await ActivityEntityQuery().entities(matching: "baignade")

        XCTAssertEqual(matches.map(\.activity), [.swimming])
    }

    func testSpotKeywordsNeverClaimOfficialSources() {
        for entity in SpotEntity.all {
            for word in entity.keywords {
                XCTAssertFalse(word.localizedCaseInsensitiveContains("SHOM"))
                XCTAssertFalse(word.localizedCaseInsensitiveContains("officiel"))
            }
        }
    }
}
