import EstranCore
import XCTest

final class EstranCoreSmokeTests: XCTestCase {
    func testCoreLinksIntoTheAppTestBundle() {
        XCTAssertEqual(EstranAppGroup.identifier, "group.com.forgedigitale.estran")
        XCTAssertEqual(Activity.allCases.count, 5)
    }
}
