@testable import EstranCore
import XCTest

final class ActivityTests: XCTestCase {
    func testFiveActivitiesAreDeclared() {
        XCTAssertEqual(Activity.allCases.count, 5)
    }

    func testEveryActivityHasFrenchCopyAndSymbol() {
        for activity in Activity.allCases {
            XCTAssertFalse(activity.displayName.isEmpty)
            XCTAssertFalse(activity.symbolName.isEmpty)
            XCTAssertEqual(activity.id, activity.rawValue)
        }
    }

    func testShortLabelsMatchTheSegmentedControlSpec() {
        XCTAssertEqual(
            Activity.allCases.map(\.shortLabel),
            ["Pêche", "Surf", "Bateau", "Balade", "Bain"])
    }
}
