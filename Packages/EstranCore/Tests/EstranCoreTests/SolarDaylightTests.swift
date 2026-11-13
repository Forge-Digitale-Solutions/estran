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

    // MARK: - Window span and the tide envelope (W-NIGHTFIX)

    private let novembre = DecisionFixtures.date("2026-11-13T00:00:00Z")

    /// 16:00–19:00 local (15:00Z–18:00Z): daylight at the start, dark by the
    /// end. Sunset at this latitude is around 17:30 local.
    func testWindowCrossingSunsetIsNight() {
        let window = DateInterval(
            start: novembre.addingTimeInterval(15 * 3600),
            end: novembre.addingTimeInterval(18 * 3600))

        XCTAssertTrue(SolarDaylight.isDaylight(at: window.start, coordinate: arcachon))
        XCTAssertFalse(SolarDaylight.isDaylight(at: window.end, coordinate: arcachon))
        XCTAssertTrue(SolarDaylight.isNight(in: window, coordinate: arcachon))
    }

    func testDaylightWindowIsNotNight() {
        let window = DateInterval(
            start: novembre.addingTimeInterval(9 * 3600),
            end: novembre.addingTimeInterval(12 * 3600))

        XCTAssertFalse(SolarDaylight.isNight(in: window, coordinate: arcachon))
    }

    /// Swimming keeps the conservative envelope: 09:08 after sunrise is
    /// daylight at the instant, but the tide's uncertainty reaches back into
    /// the dark, and swimming still refuses. Pêche à pied and boating no longer
    /// read the envelope (W-NIGHTFIX).
    func testSwimmingKeepsTheConservativeEnvelope() {
        let morning = novembre.addingTimeInterval(8 * 3600 + 8 * 60) // 09:08 local

        XCTAssertFalse(SolarDaylight.isNight(at: morning, coordinate: arcachon))
        XCTAssertTrue(
            SolarDaylight.isNight(at: morning, coordinate: arcachon, uncertainty: 75 * 60))
    }
}
