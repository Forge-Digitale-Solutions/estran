@testable import EstranCore
import Foundation
import XCTest

/// W-WIDGETCONF — the widget deep link that opens the app on a spot + activity.
final class WidgetDeepLinkTests: XCTestCase {
    func testURLRoundTripsTheTarget() {
        let target = WidgetDeepLink.Target(
            spotID: "arcachon-eyrac", activity: .shoreFishing)
        XCTAssertEqual(
            WidgetDeepLink.parse(WidgetDeepLink.url(spotID: target.spotID, activity: target.activity)),
            target)
    }

    func testParsesBothSpotsAndActivities() {
        for spot in SpotCatalog.v1 {
            for activity in Activity.allCases {
                let url = WidgetDeepLink.url(spotID: spot.id, activity: activity)
                XCTAssertEqual(
                    WidgetDeepLink.parse(url),
                    WidgetDeepLink.Target(spotID: spot.id, activity: activity))
            }
        }
    }

    func testRejectsForeignSchemes() throws {
        let url = try XCTUnwrap(
            URL(string: "https://example.com/open?spot=arcachon-eyrac&activity=surfing"))
        XCTAssertNil(WidgetDeepLink.parse(url))
    }

    func testRejectsUnknownSpot() throws {
        let url = WidgetDeepLink.url(spotID: "arcachon-eyrac", activity: .surfing)
        var components = try XCTUnwrap(
            URLComponents(url: url, resolvingAgainstBaseURL: false))
        components.queryItems = [
            URLQueryItem(name: "spot", value: "cap-ferret"),
            URLQueryItem(name: "activity", value: "surfing")
        ]
        let badURL = try XCTUnwrap(components.url)
        XCTAssertNil(WidgetDeepLink.parse(badURL))
    }

    func testRejectsUnknownActivity() throws {
        var components = URLComponents()
        components.scheme = WidgetDeepLink.scheme
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "spot", value: "arcachon-eyrac"),
            URLQueryItem(name: "activity", value: "kitesurf")
        ]
        let badURL = try XCTUnwrap(components.url)
        XCTAssertNil(WidgetDeepLink.parse(badURL))
    }
}
