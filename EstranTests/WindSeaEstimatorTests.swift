@testable import Estran
import EstranCore
import XCTest

/// The wind-sea estimate used inside the Bassin, where no free wave model
/// resolves the water.
final class WindSeaEstimatorTests: XCTestCase {
    func testCalmWindGivesAFlatEstimatedSea() {
        let swell = WindSeaEstimator.estimate(
            wind: Wind(speed: 0, gust: 0, directionDegrees: 250))

        XCTAssertEqual(swell.waveHeight, 0)
        XCTAssertEqual(swell.period, 0)
        XCTAssertTrue(swell.isEstimated)
        XCTAssertNil(swell.seaSurfaceTemperature, "an estimate is about waves, not water")
    }

    func testTenMetresPerSecondOverThreeKilometresIsAChop() {
        // 10 m/s = 36 km/h, the documented test case of the SMB constants.
        let swell = WindSeaEstimator.estimate(
            wind: Wind(speed: 36, gust: 50, directionDegrees: 250),
            fetchMeters: 3000)

        XCTAssertEqual(swell.waveHeight, 0.39, accuracy: 0.03)
        XCTAssertEqual(swell.period, 2.4, accuracy: 0.4)
        XCTAssertEqual(swell.directionDegrees, 250, accuracy: 0.1)
    }

    func testStrongerWindGivesABiggerSea() {
        let breeze = WindSeaEstimator.estimate(
            wind: Wind(speed: 18, gust: 24, directionDegrees: 250))
        let gale = WindSeaEstimator.estimate(
            wind: Wind(speed: 54, gust: 70, directionDegrees: 250))

        XCTAssertLessThan(breeze.waveHeight, gale.waveHeight)
        XCTAssertLessThan(breeze.period, gale.period)
    }

    func testLongerFetchGivesABiggerSea() {
        let wind = Wind(speed: 36, gust: 50, directionDegrees: 250)
        let lagoon = WindSeaEstimator.estimate(wind: wind, fetchMeters: 2000)
        let openBay = WindSeaEstimator.estimate(wind: wind, fetchMeters: 20000)

        XCTAssertLessThan(lagoon.waveHeight, openBay.waveHeight)
    }

    /// The estimate must never look like a model value in the UI or the
    /// accessibility sentence.
    func testTheConditionsLineSaysTheSeaIsEstimated() {
        let conditions = Conditions(
            spot: SpotCatalog.arcachonEyrac,
            at: Date(timeIntervalSince1970: 1_793_000_000),
            tide: TideState(
                current: nil,
                next: nil,
                coefficient: 80,
                curve: []),
            weather: WeatherNow(
                temperature: 18,
                condition: .clear,
                precipitationChance: 0,
                cloudCover: 0.2,
                wind: Wind(speed: 18, gust: 24, directionDegrees: 250),
                visibility: 20000),
            swell: WindSeaEstimator.estimate(
                wind: Wind(speed: 18, gust: 24, directionDegrees: 250)))

        let line = SwimmingAdvisory.conditionsLine(for: conditions)
        XCTAssertTrue(line.contains("houle estimée"), "got: \(line)")
        XCTAssertTrue(line.contains("eau indisponible"), "no lagoon water temperature is invented")
    }
}
