@testable import EstranCore
import XCTest

final class SolarDaylightTests: XCTestCase {
    private let arcachon = DecisionFixtures.arcachon.coordinate

    func testSummerNoonIsHigh() {
        let date = DecisionFixtures.date("2026-06-21T12:00:00Z")
        let elevation = SolarDaylight.solarElevationDegrees(at: date, coordinate: arcachon)
        XCTAssertGreaterThan(elevation, 60)
        XCTAssertTrue(SolarDaylight.isDaylight(at: date, coordinate: arcachon))
    }

    func testWinterNoonIsLower() {
        let date = DecisionFixtures.date("2026-12-21T12:00:00Z")
        let elevation = SolarDaylight.solarElevationDegrees(at: date, coordinate: arcachon)
        XCTAssertGreaterThan(elevation, 15)
        XCTAssertLessThan(elevation, 30)
    }

    func testNightIsBelowTheHorizon() {
        let date = DecisionFixtures.date("2026-06-21T01:00:00Z")
        let elevation = SolarDaylight.solarElevationDegrees(at: date, coordinate: arcachon)
        XCTAssertLessThan(elevation, 0)
        XCTAssertFalse(SolarDaylight.isDaylight(at: date, coordinate: arcachon))
    }

    func testSouthernHemisphereIsInverted() {
        let date = DecisionFixtures.date("2026-06-21T12:00:00Z")
        let north = SolarDaylight.solarElevationDegrees(at: date, coordinate: arcachon)
        let south = SolarDaylight.solarElevationDegrees(
            at: date,
            coordinate: Coordinate(latitude: -44.66, longitude: -1.17))
        XCTAssertGreaterThan(north, south)
    }
}
