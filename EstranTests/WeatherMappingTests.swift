@testable import Estran
import EstranCore
import XCTest

#if canImport(WeatherKit)
    import WeatherKit
#endif

/// The two air-weather adapters map their source conditions onto the domain's
/// ten conditions, keeping light rain (`.drizzle`) distinct from franc rain so
/// the rain-gated activities can tolerate a drizzle (owner decision 2026-11-12).
final class WeatherMappingTests: XCTestCase {
    // MARK: - Open-Meteo (WMO 4677)

    func testOpenMeteoDrizzleAndSlightRainMapToDrizzle() {
        for code in [51, 53, 55, 56, 57, 61] {
            XCTAssertEqual(OpenMeteoWeatherService.condition(forWMO: code), .drizzle, "WMO \(code)")
        }
    }

    func testOpenMeteoModerateAndHeavyRainMapToRain() {
        for code in [63, 65, 66, 67] {
            XCTAssertEqual(OpenMeteoWeatherService.condition(forWMO: code), .rain, "WMO \(code)")
        }
    }

    func testOpenMeteoShowersMapToShowers() {
        for code in [80, 81, 82] {
            XCTAssertEqual(OpenMeteoWeatherService.condition(forWMO: code), .showers, "WMO \(code)")
        }
    }

    func testOpenMeteoThunderstormsMapToThunderstorm() {
        for code in [95, 96, 99] {
            XCTAssertEqual(OpenMeteoWeatherService.condition(forWMO: code), .thunderstorm, "WMO \(code)")
        }
    }

    func testOpenMeteoClearCloudyFogAndSnow() {
        XCTAssertEqual(OpenMeteoWeatherService.condition(forWMO: 0), .clear)
        XCTAssertEqual(OpenMeteoWeatherService.condition(forWMO: 1), .clear)
        XCTAssertEqual(OpenMeteoWeatherService.condition(forWMO: 2), .partlyCloudy)
        XCTAssertEqual(OpenMeteoWeatherService.condition(forWMO: 3), .cloudy)
        XCTAssertEqual(OpenMeteoWeatherService.condition(forWMO: 45), .fog)
        XCTAssertEqual(OpenMeteoWeatherService.condition(forWMO: 71), .snow)
    }

    // MARK: - WeatherKit

    #if canImport(WeatherKit)
        func testWeatherKitDrizzleMapsToDrizzle() {
            XCTAssertEqual(WeatherKitService.map(.drizzle), .drizzle)
            XCTAssertEqual(WeatherKitService.map(.freezingDrizzle), .drizzle)
        }

        func testWeatherKitFrancRainMapsToRain() {
            XCTAssertEqual(WeatherKitService.map(.rain), .rain)
            XCTAssertEqual(WeatherKitService.map(.heavyRain), .rain)
            XCTAssertEqual(WeatherKitService.map(.freezingRain), .rain)
        }

        func testWeatherKitSunShowersMapToShowers() {
            XCTAssertEqual(WeatherKitService.map(.sunShowers), .showers)
        }

        func testWeatherKitThunderstormsMapToThunderstorm() {
            XCTAssertEqual(WeatherKitService.map(.thunderstorms), .thunderstorm)
            XCTAssertEqual(WeatherKitService.map(.isolatedThunderstorms), .thunderstorm)
            XCTAssertEqual(WeatherKitService.map(.scatteredThunderstorms), .thunderstorm)
        }

        func testWeatherKitClearAndCloudy() {
            XCTAssertEqual(WeatherKitService.map(.clear), .clear)
            XCTAssertEqual(WeatherKitService.map(.partlyCloudy), .partlyCloudy)
            XCTAssertEqual(WeatherKitService.map(.cloudy), .cloudy)
            XCTAssertEqual(WeatherKitService.map(.foggy), .fog)
        }
    #endif
}
