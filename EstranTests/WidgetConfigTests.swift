@testable import Estran
import EstranCore
import XCTest

/// W-WIDGETCONF — the configurable-widget data path and the calm-sea tile fix.
final class WidgetConfigTests: XCTestCase {
    // MARK: - Calm estimated sea (invariant 3: never a bare 0,0 m)

    func testCalmEstimatedSwellReadsCalmeNotZero() {
        let calm = Swell(
            waveHeight: 0.05, period: 0, directionDegrees: 250,
            seaSurfaceTemperature: nil, source: .windSeaEstimate)

        XCTAssertEqual(FrenchFormat.swellHeight(calm), "Calme")
    }

    func testEstimatedSwellAtOrAboveThresholdKeepsItsHeight() {
        let chop = Swell(
            waveHeight: 0.39, period: 2.4, directionDegrees: 250,
            seaSurfaceTemperature: nil, source: .windSeaEstimate)

        XCTAssertEqual(FrenchFormat.swellHeight(chop), "≈ 0,4 m")
    }

    func testModelSwellIsNeverReplacedByCalme() {
        // A measured 0.05 m is a real height, not a wind-sea estimate: it must
        // stay a number, never the « Calme » word reserved for the estimate.
        let tiny = Swell(
            waveHeight: 0.05, period: 8, directionDegrees: 280,
            seaSurfaceTemperature: 14, source: .model)

        XCTAssertEqual(FrenchFormat.swellHeight(tiny), "0,1 m")
    }

    // MARK: - Widget tap routing

    @MainActor
    func testOpenWidgetSelectsTheSpotAndActivity() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "EstranTests.WidgetConfig.\(UUID().uuidString)"))
        let app = AppModel(
            provider: StubWidgetConditionsProvider(),
            selectionStorage: SpotSelectionStorage(defaults: defaults),
            intentSelection: IntentSelectionStorage(defaults: defaults),
            activityStorage: ActivitySelectionStorage(defaults: defaults),
            reasonProvider: TemplateReasonProvider())

        await app.openWidget(spotID: "arcachon-eyrac", activity: .boating)

        XCTAssertEqual(app.selectedSpot.id, "arcachon-eyrac")
        XCTAssertEqual(app.activity, .boating)
    }

    @MainActor
    func testOpenWidgetOnTheSameSpotRefreshesTheActivity() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "EstranTests.WidgetConfig.\(UUID().uuidString)"))
        let app = AppModel(
            provider: StubWidgetConditionsProvider(),
            selectionStorage: SpotSelectionStorage(defaults: defaults),
            intentSelection: IntentSelectionStorage(defaults: defaults),
            activityStorage: ActivitySelectionStorage(defaults: defaults),
            reasonProvider: TemplateReasonProvider())

        // Default spot is Pointe de Grave; changing only the activity must still
        // refresh the decision, not just the chip.
        await app.openWidget(spotID: "pointe-de-grave", activity: .surfing)

        XCTAssertEqual(app.selectedSpot.id, "pointe-de-grave")
        XCTAssertEqual(app.activity, .surfing)
    }
}

/// Deterministic conditions for whatever spot it is asked for, no network.
private struct StubWidgetConditionsProvider: ConditionsProviding {
    let isSampleData = true

    func conditions(for spot: Spot, at date: Date) async throws -> Conditions {
        Self.conditions(spot: spot, at: date)
    }

    func forecast(for spot: Spot, from date: Date, hours: Int) async throws -> [Conditions] {
        (0 ..< max(hours, 1)).map { hour in
            Self.conditions(spot: spot, at: date.addingTimeInterval(Double(hour) * 3600))
        }
    }

    static func conditions(spot: Spot, at date: Date) -> Conditions {
        Conditions(
            spot: spot,
            at: date,
            tide: TideState(
                current: TideEvent(time: date.addingTimeInterval(-3600), kind: .low, height: 0.88),
                next: TideEvent(time: date.addingTimeInterval(3 * 3600), kind: .high, height: 4.2),
                coefficient: 85,
                curve: [TidePoint(time: date.addingTimeInterval(-3600), height: 0.88)]),
            weather: WeatherNow(
                temperature: 16,
                condition: .partlyCloudy,
                precipitationChance: 0.1,
                cloudCover: 0.4,
                wind: Wind(speed: 12, gust: 20, directionDegrees: 250),
                visibility: 20000),
            swell: Swell(
                waveHeight: 1.2, period: 9, directionDegrees: 280,
                seaSurfaceTemperature: 17, source: .model))
    }
}
