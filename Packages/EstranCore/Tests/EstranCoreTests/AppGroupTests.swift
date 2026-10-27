@testable import EstranCore
import XCTest

final class AppGroupTests: XCTestCase {
    func testAppGroupIdentifierIsStable() {
        XCTAssertEqual(EstranAppGroup.identifier, "group.com.forgedigitale.estran")
    }
}
