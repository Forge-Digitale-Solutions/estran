@testable import EstranCore
import Foundation

/// Golden decision scenarios.
///
/// Each case pins the exact score produced by the documented weights, the
/// blockers it must report, and the resulting Oui/Non. Scores are independent
/// reference values, not values captured from the implementation.
struct GoldenScenario {
    let name: String
    let activity: Activity
    let conditions: Conditions
    let expectedGo: Bool
    let expectedScore: Double
    let expectedBlockers: [ActivityBlocker]
}

enum GoldenScenarios {
    static let noon = DecisionFixtures.date("2026-06-21T10:00:00Z")
    static let summerNoonUTC = DecisionFixtures.date("2026-06-21T12:00:00Z")
    static let summerNightUTC = DecisionFixtures.date("2026-06-21T01:00:00Z")

    static let all: [GoldenScenario] = primaryScenarios + gateScenarios
}

extension GoldenScenarios {
    static let primaryScenarios: [GoldenScenario] = [
        GoldenScenario(
            name: "shore fishing ideal",
            activity: .shoreFishing,
            conditions: DecisionFixtures.conditions(
                at: noon,
                tide: DecisionFixtures.tide(at: noon, coefficient: 95, minutesSinceCurrent: 40),
                weather: DecisionFixtures.weather(windSpeed: 8, windGust: 12)),
            expectedGo: true,
            expectedScore: 1.0,
            expectedBlockers: []),
        GoldenScenario(
            name: "shore fishing coefficient blocker",
            activity: .shoreFishing,
            conditions: DecisionFixtures.conditions(
                at: noon,
                tide: DecisionFixtures.tide(at: noon, coefficient: 45, minutesSinceCurrent: 40),
                weather: DecisionFixtures.weather(windSpeed: 8, windGust: 12)),
            expectedGo: false,
            expectedScore: 0.65,
            expectedBlockers: [.coefficient]),
        GoldenScenario(
            name: "surf ideal",
            activity: .surfing,
            conditions: DecisionFixtures.conditions(
                at: noon,
                tide: DecisionFixtures.tide(at: noon, coefficient: 95, minutesSinceCurrent: 60),
                weather: DecisionFixtures.weather(windSpeed: 10, windGust: 15, windDirection: 90),
                swell: DecisionFixtures.swell(waveHeight: 1.5, period: 11, directionDegrees: 270)),
            expectedGo: true,
            expectedScore: 1.0,
            expectedBlockers: []),
        GoldenScenario(
            name: "surf strong onshore wind",
            activity: .surfing,
            conditions: DecisionFixtures.conditions(
                at: noon,
                tide: DecisionFixtures.tide(at: noon, coefficient: 95, minutesSinceCurrent: 60),
                weather: DecisionFixtures.weather(windSpeed: 30, windGust: 40, windDirection: 270),
                swell: DecisionFixtures.swell(waveHeight: 1.5, period: 11, directionDegrees: 270)),
            expectedGo: false,
            expectedScore: 0.75,
            expectedBlockers: [.wind, .onshoreWind]),
        GoldenScenario(
            name: "surf flat sea",
            activity: .surfing,
            conditions: DecisionFixtures.conditions(
                at: noon,
                tide: DecisionFixtures.tide(at: noon, coefficient: 95, minutesSinceCurrent: 60),
                weather: DecisionFixtures.weather(windSpeed: 10, windGust: 15, windDirection: 90),
                swell: DecisionFixtures.swell(waveHeight: 0.3, period: 11, directionDegrees: 270)),
            expectedGo: false,
            expectedScore: 0.65,
            expectedBlockers: [.waveTooSmall]),
        GoldenScenario(
            name: "boating ideal",
            activity: .boating,
            conditions: DecisionFixtures.conditions(
                at: noon,
                tide: DecisionFixtures.tide(at: noon, coefficient: 95, minutesSinceCurrent: 60),
                weather: DecisionFixtures.weather(windSpeed: 12, windGust: 18),
                swell: DecisionFixtures.swell(waveHeight: 0.6, period: 8)),
            expectedGo: true,
            expectedScore: 1.0,
            expectedBlockers: []),
        GoldenScenario(
            name: "boating fog",
            activity: .boating,
            conditions: DecisionFixtures.conditions(
                at: noon,
                tide: DecisionFixtures.tide(at: noon, coefficient: 95, minutesSinceCurrent: 60),
                weather: DecisionFixtures.weather(
                    condition: .fog,
                    windSpeed: 12,
                    windGust: 18,
                    visibility: 500),
                swell: DecisionFixtures.swell(waveHeight: 0.6, period: 8)),
            expectedGo: false,
            expectedScore: 0.85,
            expectedBlockers: [.fog]),
        GoldenScenario(
            name: "walk ideal",
            activity: .walking,
            conditions: DecisionFixtures.conditions(
                at: noon,
                tide: DecisionFixtures.tide(at: noon),
                weather: DecisionFixtures.weather(temperature: 22, precipitationChance: 0.05, windSpeed: 10)),
            expectedGo: true,
            expectedScore: 1.0,
            expectedBlockers: []),
        GoldenScenario(
            name: "walk rain",
            activity: .walking,
            conditions: DecisionFixtures.conditions(
                at: noon,
                tide: DecisionFixtures.tide(at: noon),
                weather: DecisionFixtures.weather(
                    temperature: 22,
                    condition: .rain,
                    precipitationChance: 0.8,
                    windSpeed: 10)),
            expectedGo: false,
            expectedScore: 0.6,
            expectedBlockers: [.rain]),
        GoldenScenario(
            name: "swim ideal",
            activity: .swimming,
            conditions: DecisionFixtures.conditions(
                at: summerNoonUTC,
                tide: DecisionFixtures.tide(at: summerNoonUTC, coefficient: 80, minutesSinceCurrent: 60),
                weather: DecisionFixtures.weather(temperature: 24, windSpeed: 10),
                swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: 20)),
            expectedGo: true,
            expectedScore: 1.0,
            expectedBlockers: []),
        GoldenScenario(
            name: "swim cold water",
            activity: .swimming,
            conditions: DecisionFixtures.conditions(
                at: summerNoonUTC,
                tide: DecisionFixtures.tide(at: summerNoonUTC, coefficient: 80, minutesSinceCurrent: 60),
                weather: DecisionFixtures.weather(temperature: 24, windSpeed: 10),
                swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: 15)),
            expectedGo: false,
            expectedScore: 0.75,
            expectedBlockers: [.waterTemperature]),
        GoldenScenario(
            name: "swim at night",
            activity: .swimming,
            conditions: DecisionFixtures.conditions(
                at: summerNightUTC,
                tide: DecisionFixtures.tide(at: summerNightUTC, coefficient: 80, minutesSinceCurrent: 60),
                weather: DecisionFixtures.weather(temperature: 24, windSpeed: 10),
                swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: 20)),
            expectedGo: false,
            expectedScore: 0.9,
            expectedBlockers: [.night]),
        GoldenScenario(
            name: "swim strong current",
            activity: .swimming,
            conditions: DecisionFixtures.conditions(
                at: summerNoonUTC,
                tide: DecisionFixtures.tide(
                    at: summerNoonUTC,
                    coefficient: 105,
                    minutesSinceCurrent: 180,
                    minutesToNext: 180),
                weather: DecisionFixtures.weather(temperature: 24, windSpeed: 10),
                swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: 20),
                spot: DecisionFixtures.swimmingStrongSpot),
            expectedGo: false,
            expectedScore: 0.96,
            expectedBlockers: [.strongCurrent])
    ]
}

extension GoldenScenarios {
    static let gateScenarios: [GoldenScenario] = [
        GoldenScenario(
            name: "shore fishing high water",
            activity: .shoreFishing,
            conditions: DecisionFixtures.conditions(
                at: noon,
                tide: DecisionFixtures.tide(
                    at: noon,
                    coefficient: 95,
                    currentKind: .high,
                    currentHeight: 4.4,
                    nextKind: .low,
                    nextHeight: 0.4,
                    minutesSinceCurrent: 60,
                    minutesToNext: 320),
                weather: DecisionFixtures.weather(windSpeed: 8, windGust: 12)),
            expectedGo: false,
            expectedScore: 0.70,
            expectedBlockers: [.tideTiming]),
        GoldenScenario(
            name: "shore fishing coefficient at the gate",
            activity: .shoreFishing,
            conditions: DecisionFixtures.conditions(
                at: noon,
                tide: DecisionFixtures.tide(at: noon, coefficient: 50, minutesSinceCurrent: 40),
                weather: DecisionFixtures.weather(windSpeed: 8, windGust: 12)),
            expectedGo: false,
            expectedScore: 0.65,
            expectedBlockers: [.coefficient]),
        GoldenScenario(
            name: "shore fishing without a low-water event",
            activity: .shoreFishing,
            conditions: DecisionFixtures.conditions(
                at: noon,
                tide: TideState(
                    current: TideEvent(time: noon, kind: .high, height: 4.4),
                    next: nil,
                    coefficient: 95,
                    coefficientSource: .nationalBrest,
                    coefficientValidated: true,
                    curve: []),
                weather: DecisionFixtures.weather(windSpeed: 8, windGust: 12)),
            expectedGo: false,
            expectedScore: 0.70,
            expectedBlockers: [.dataUnavailable]),
        GoldenScenario(
            name: "surf short period",
            activity: .surfing,
            conditions: DecisionFixtures.conditions(
                at: noon,
                tide: DecisionFixtures.tide(at: noon, coefficient: 95, minutesSinceCurrent: 60),
                weather: DecisionFixtures.weather(windSpeed: 10, windGust: 15, windDirection: 90),
                swell: DecisionFixtures.swell(waveHeight: 1.5, period: 6, directionDegrees: 270)),
            expectedGo: false,
            expectedScore: 0.866_666_666_666_666_6,
            expectedBlockers: [.wavePeriod]),
        GoldenScenario(
            name: "boating swell at the gate",
            activity: .boating,
            conditions: DecisionFixtures.conditions(
                at: noon,
                tide: DecisionFixtures.tide(at: noon, coefficient: 95, minutesSinceCurrent: 60),
                weather: DecisionFixtures.weather(windSpeed: 12, windGust: 18),
                swell: DecisionFixtures.swell(waveHeight: 1.2, period: 8)),
            expectedGo: false,
            expectedScore: 0.828_571_428_571_428_6,
            expectedBlockers: [.swellTooLarge]),
        GoldenScenario(
            name: "boating without a tide curve",
            activity: .boating,
            conditions: DecisionFixtures.conditions(
                at: noon,
                tide: TideState(
                    current: TideEvent(time: noon.addingTimeInterval(-3600), kind: .low, height: 0.4),
                    next: TideEvent(time: noon.addingTimeInterval(320 * 60), kind: .high, height: 4.4),
                    coefficient: 95,
                    curve: []),
                weather: DecisionFixtures.weather(windSpeed: 12, windGust: 18),
                swell: DecisionFixtures.swell(waveHeight: 0.6, period: 8)),
            expectedGo: false,
            expectedScore: 0.80,
            expectedBlockers: [.dataUnavailable]),
        GoldenScenario(
            name: "swim water at the gate",
            activity: .swimming,
            conditions: DecisionFixtures.conditions(
                at: summerNoonUTC,
                tide: DecisionFixtures.tide(at: summerNoonUTC, coefficient: 80, minutesSinceCurrent: 60),
                weather: DecisionFixtures.weather(temperature: 24, windSpeed: 10),
                swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: 16)),
            expectedGo: false,
            expectedScore: 0.75,
            expectedBlockers: [.waterTemperature]),
        GoldenScenario(
            name: "swim without a sea-surface temperature",
            activity: .swimming,
            conditions: DecisionFixtures.conditions(
                at: summerNoonUTC,
                tide: DecisionFixtures.tide(at: summerNoonUTC, coefficient: 80, minutesSinceCurrent: 60),
                weather: DecisionFixtures.weather(temperature: 24, windSpeed: 10),
                swell: DecisionFixtures.swell(waveHeight: 0.5, seaSurfaceTemperature: nil)),
            expectedGo: false,
            expectedScore: 0.75,
            expectedBlockers: [.dataUnavailable]),
        GoldenScenario(
            name: "swim strong wind and swell",
            activity: .swimming,
            conditions: DecisionFixtures.conditions(
                at: summerNoonUTC,
                tide: DecisionFixtures.tide(at: summerNoonUTC, coefficient: 80, minutesSinceCurrent: 60),
                weather: DecisionFixtures.weather(temperature: 24, windSpeed: 30),
                swell: DecisionFixtures.swell(waveHeight: 1.2, seaSurfaceTemperature: 20)),
            expectedGo: false,
            expectedScore: 0.752_380_952_380_952_4,
            expectedBlockers: [.wind, .swellTooLarge]),
        GoldenScenario(
            name: "walk strong wind and cold air",
            activity: .walking,
            conditions: DecisionFixtures.conditions(
                at: noon,
                tide: DecisionFixtures.tide(at: noon),
                weather: DecisionFixtures.weather(temperature: 5, precipitationChance: 0, windSpeed: 35)),
            expectedGo: false,
            expectedScore: 0.76,
            expectedBlockers: [.wind, .temperature])
    ]
}
