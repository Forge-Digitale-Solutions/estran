@testable import Estran
import EstranCore
import XCTest

/// M2 — Open-Meteo Marine decoder, cache and per-spot policy.
///
/// The payloads below are trimmed from a real `marine-api.open-meteo.com`
/// response (Pointe de Grave, 2026-10-28) so the decoder is tested against the
/// shape the service actually returns, not against a convenient one.
final class MarineServiceTests: XCTestCase {
    // MARK: - Decoding

    func testDecodesThreeHours() throws {
        let samples = try MarineService.decode(Data(Self.validPayload.utf8))

        XCTAssertEqual(samples.count, 3)
        let first = try XCTUnwrap(samples.first)
        XCTAssertEqual(first.swell.waveHeight, 1.16, accuracy: 0.001)
        XCTAssertEqual(first.swell.period, 11.6, accuracy: 0.001)
        XCTAssertEqual(first.swell.directionDegrees, 278, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(first.swell.seaSurfaceTemperature), 15.7, accuracy: 0.001)
        XCTAssertEqual(
            first.time,
            Self.date("2026-10-28T00:00"),
            "timestamps are parsed in UTC, never in the device zone")
    }

    func testDropsTheHourWithoutWaveHeight() throws {
        let samples = try MarineService.decode(Data(Self.missingWaveHeightPayload.utf8))

        XCTAssertEqual(samples.count, 2, "a null wave height is a missing hour, not a calm sea")
        XCTAssertFalse(
            samples.contains { $0.time == Self.date("2026-10-28T01:00") },
            "the hour with no wave must not appear in the forecast at all")
    }

    func testKeepsTheHourWhenOnlyTheSeaTemperatureIsMissing() throws {
        let samples = try MarineService.decode(Data(Self.missingSeaTemperaturePayload.utf8))

        XCTAssertEqual(samples.count, 3)
        XCTAssertNil(
            samples[1].swell.seaSurfaceTemperature,
            "a missing sea temperature is a visible null, never 0 °C")
        XCTAssertEqual(samples[1].swell.waveHeight, 1.16, accuracy: 0.001)
    }

    func testRejectsAPayloadWithMissingArrays() {
        XCTAssertThrowsError(try MarineService.decode(Data(Self.truncatedPayload.utf8))) { error in
            XCTAssertEqual(error as? ConditionsProviderError, .marineUnavailable)
        }
    }

    func testRejectsMalformedJSON() {
        XCTAssertThrowsError(try MarineService.decode(Data("{ not json".utf8))) { error in
            XCTAssertEqual(error as? ConditionsProviderError, .marineUnavailable)
        }
    }

    func testRejectsAnEmptySeries() {
        XCTAssertThrowsError(try MarineService.decode(Data(Self.emptyPayload.utf8))) { error in
            XCTAssertEqual(error as? ConditionsProviderError, .marineUnavailable)
        }
    }

    // MARK: - Cache

    func testCacheRoundTripAndFreshness() async throws {
        let cache = MarineCache(directory: Self.temporaryDirectory())
        let now = Self.date("2026-10-28T12:00")
        let samples = try MarineService.decode(Data(Self.validPayload.utf8))

        await cache.store(samples, for: "pointe-de-grave", now: now)

        let read = await cache.samples(for: "pointe-de-grave", now: now.addingTimeInterval(60))
        XCTAssertEqual(read, samples, "the cache must round-trip the exact samples")
        let fresh = await cache.isFresh(for: "pointe-de-grave", now: now.addingTimeInterval(60))
        XCTAssertTrue(fresh)
    }

    func testCacheIsIgnoredAfterTheStaleWindow() async throws {
        let cache = MarineCache(directory: Self.temporaryDirectory())
        let now = Self.date("2026-10-28T12:00")
        let samples = try MarineService.decode(Data(Self.validPayload.utf8))
        await cache.store(samples, for: "pointe-de-grave", now: now)

        let read = await cache.samples(
            for: "pointe-de-grave",
            now: now.addingTimeInterval(MarineCache.staleInterval + 60))
        XCTAssertNil(read, "an old sea is not shown: past the stale window there is no data")
    }

    func testCacheIsPerSpot() async throws {
        let cache = MarineCache(directory: Self.temporaryDirectory())
        let now = Self.date("2026-10-28T12:00")
        let samples = try MarineService.decode(Data(Self.validPayload.utf8))
        await cache.store(samples, for: "pointe-de-grave", now: now)

        let other = await cache.samples(for: "arcachon-eyrac", now: now)
        XCTAssertNil(other)
    }

    // MARK: - Policy

    func testOnlyTheOceanSpotUsesTheOffshoreModel() {
        XCTAssertEqual(MarinePolicy.source(for: SpotCatalog.pointeDeGrave), .offshoreModel)
        XCTAssertEqual(MarinePolicy.source(for: SpotCatalog.arcachonEyrac), .unavailable)
    }

    func testNearestSwellRejectsASampleOutsideTheTolerance() throws {
        let samples = try MarineService.decode(Data(Self.validPayload.utf8))
        let inside = LiveConditionsProvider.nearestSwell(
            in: samples, to: Self.date("2026-10-28T00:30"))
        XCTAssertNotNil(inside)
        let outside = LiveConditionsProvider.nearestSwell(
            in: samples, to: Self.date("2026-10-28T06:00"))
        XCTAssertNil(outside, "five hours away is not this hour's sea")
    }

    // MARK: - Helpers

    private static func date(_ iso: String) -> Date {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = .gmt
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return parser.date(from: iso) ?? .distantPast
    }

    private static func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("marine-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static let validPayload = """
    {
      "latitude": 45.57, "longitude": -1.06,
      "utc_offset_seconds": 0, "timezone": "UTC",
      "hourly": {
        "time": ["2026-10-28T00:00", "2026-10-28T01:00", "2026-10-28T02:00"],
        "wave_height": [1.16, 1.16, 1.14],
        "wave_period": [11.6, 11.65, 11.7],
        "wave_direction": [278, 279, 279],
        "sea_surface_temperature": [15.7, 15.7, 15.6]
      }
    }
    """

    private static let missingWaveHeightPayload = """
    {
      "hourly": {
        "time": ["2026-10-28T00:00", "2026-10-28T01:00", "2026-10-28T02:00"],
        "wave_height": [1.16, null, 1.14],
        "wave_period": [11.6, 11.65, 11.7],
        "wave_direction": [278, 279, 279],
        "sea_surface_temperature": [15.7, 15.7, 15.6]
      }
    }
    """

    private static let missingSeaTemperaturePayload = """
    {
      "hourly": {
        "time": ["2026-10-28T00:00", "2026-10-28T01:00", "2026-10-28T02:00"],
        "wave_height": [1.16, 1.16, 1.14],
        "wave_period": [11.6, 11.65, 11.7],
        "wave_direction": [278, 279, 279],
        "sea_surface_temperature": [15.7, null, 15.6]
      }
    }
    """

    private static let truncatedPayload = """
    {
      "hourly": {
        "time": ["2026-10-28T00:00", "2026-10-28T01:00"],
        "wave_height": [1.16],
        "wave_period": [11.6],
        "wave_direction": [278]
      }
    }
    """

    private static let emptyPayload = """
    {
      "hourly": {
        "time": [],
        "wave_height": [],
        "wave_period": [],
        "wave_direction": [],
        "sea_surface_temperature": []
      }
    }
    """
}
