@testable import EstranCore
import XCTest

final class SpotSelectionStorageTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "estran.tests.selection.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testRoundTrip() {
        let storage = SpotSelectionStorage(defaults: defaults)
        XCTAssertNil(storage.load())
        storage.save("arcachon-eyrac")
        XCTAssertEqual(storage.load(), "arcachon-eyrac")
        XCTAssertEqual(SpotSelectionStorage(defaults: defaults).load(), "arcachon-eyrac")
    }

    func testEmptyIdentifierIsIgnored() {
        let storage = SpotSelectionStorage(defaults: defaults)
        storage.save("pointe-de-grave")
        storage.save("")
        XCTAssertEqual(storage.load(), "pointe-de-grave")
    }

    func testClearFallsBackToTheDefault() {
        let storage = SpotSelectionStorage(defaults: defaults)
        storage.save("arcachon-eyrac")
        storage.clear()
        XCTAssertNil(storage.load())
        XCTAssertEqual(SpotCatalog.spot(id: storage.load()).id, SpotCatalog.defaultSpot.id)
    }

    func testMissingDefaultsNeverCrashes() {
        let storage = SpotSelectionStorage(defaults: nil)
        XCTAssertNil(storage.load())
        storage.save("arcachon-eyrac")
        XCTAssertNil(storage.load())
    }
}
