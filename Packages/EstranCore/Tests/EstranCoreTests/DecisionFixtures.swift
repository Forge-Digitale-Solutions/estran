@testable import EstranCore
import Foundation

/// Deterministic conditions used by the domain tests.
///
/// The spot coordinates and station references are test fixtures, not the
/// confirmed production catalog.
enum DecisionFixtures {
    static let timezone = TimeZone(identifier: "Europe/Paris") ?? .gmt

    static func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso) ?? Date(timeIntervalSince1970: 0)
    }

    static let arcachon = Spot(
        id: "arcachon-eyrac",
        name: "Arcachon — Eyrac",
        region: .bassin,
        coordinate: Coordinate(latitude: 44.66, longitude: -1.17),
        tideStation: TideStationRef(id: "arcachon-eyrac", name: "Arcachon-Eyrac"),
        supportedActivities: Set(Activity.allCases),
        timezone: timezone,
        coastOrientationDegrees: 270,
        minimumWaterHeight: 1.0,
        // The standard fixture curve spans 4.0 m; this range keeps it low.
        swimmingRange: SwimmingRange(lowBelow: 4.5, strongAt: 5.0))

    /// Same spot, with a range low enough that the 4.0 m fixture curve is
    /// strong at mid-tide. Used by the current-level tests.
    static let swimmingStrongSpot = Spot(
        id: "arcachon-eyrac",
        name: "Arcachon — Eyrac",
        region: .bassin,
        coordinate: Coordinate(latitude: 44.66, longitude: -1.17),
        tideStation: TideStationRef(id: "arcachon-eyrac", name: "Arcachon-Eyrac"),
        supportedActivities: Set(Activity.allCases),
        timezone: timezone,
        coastOrientationDegrees: 270,
        minimumWaterHeight: 1.0,
        swimmingRange: SwimmingRange(lowBelow: 3.0, strongAt: 3.5))

    static func weather(
        temperature: Double = 20,
        condition: WeatherCondition = .clear,
        precipitationChance: Double = 0,
        windSpeed: Double = 10,
        windGust: Double = 15,
        windDirection: Double = 90,
        visibility: Double = 20000) -> WeatherNow
    {
        WeatherNow(
            temperature: temperature,
            condition: condition,
            precipitationChance: precipitationChance,
            cloudCover: 0.2,
            wind: Wind(speed: windSpeed, gust: windGust, directionDegrees: windDirection),
            visibility: visibility)
    }

    static func swell(
        waveHeight: Double = 1.0,
        period: Double = 10,
        directionDegrees: Double = 270,
        seaSurfaceTemperature: Double? = 19) -> Swell
    {
        Swell(
            waveHeight: waveHeight,
            period: period,
            directionDegrees: directionDegrees,
            seaSurfaceTemperature: seaSurfaceTemperature)
    }

    /// Tide state whose last event is `minutesSinceCurrent` before `date` and
    /// whose next event is `minutesToNext` after it.
    ///
    /// The curve interpolates linearly between both events and stays **flat**
    /// for three hours on each side, so the interval helpers always see a
    /// covered window (review Z15) without inventing extrema below the declared
    /// low water. Enough for rule and interval tests; not a tide model.
    static func tide(
        at date: Date,
        coefficient: Int = 95,
        coefficientSource: TideState.CoefficientSource = .nationalBrest,
        coefficientValidated: Bool = true,
        currentKind: TideEvent.Kind = .low,
        currentHeight: Double = 0.4,
        nextKind: TideEvent.Kind = .high,
        nextHeight: Double = 4.4,
        minutesSinceCurrent: Double = 60,
        minutesToNext: Double = 320) -> TideState
    {
        let currentTime = date.addingTimeInterval(-minutesSinceCurrent * 60)
        let nextTime = date.addingTimeInterval(minutesToNext * 60)
        let current = TideEvent(time: currentTime, kind: currentKind, height: currentHeight)
        let next = TideEvent(time: nextTime, kind: nextKind, height: nextHeight)

        var curve: [TidePoint] = []
        let total = nextTime.timeIntervalSince(currentTime)
        let step: TimeInterval = 10 * 60
        let margin: TimeInterval = 3 * 3600
        var offset: TimeInterval = -margin
        while offset <= total + margin {
            let height: Double = if offset <= 0 {
                currentHeight
            } else if offset >= total {
                nextHeight
            } else {
                currentHeight + (nextHeight - currentHeight) * (offset / total)
            }
            curve.append(
                TidePoint(
                    time: currentTime.addingTimeInterval(offset),
                    height: height))
            offset += step
        }
        return TideState(
            current: current,
            next: next,
            coefficient: coefficient,
            // Fixtures model the post-Z23 state: a national coefficient from
            // Brest. `coefficientValidated` is explicit so a test can model the
            // unvalidated model the app actually ships.
            coefficientSource: coefficientSource,
            coefficientValidated: coefficientValidated,
            curve: curve)
    }

    static func conditions(
        at date: Date,
        tide: TideState,
        weather: WeatherNow = DecisionFixtures.weather(),
        swell: Swell = DecisionFixtures.swell(),
        spot: Spot = DecisionFixtures.arcachon) -> Conditions
    {
        Conditions(spot: spot, at: date, tide: tide, weather: weather, swell: swell)
    }
}
