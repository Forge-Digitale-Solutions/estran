@testable import EstranCore
import XCTest

/// Unit tests for the harmonic tide engine, driven only by synthetic
/// fixtures (see `TideFixtures`).
final class TideEngineTests: XCTestCase {
    private let predictor = HarmonicPredictor()

    // MARK: Height of the M2 extrema

    func testHeightAtAbsoluteModelEpoch() {
        // Independent absolute check of the time base: at the model epoch with
        // phase 0, the M2 cosine is 1, so the height is Z0 + H. A wrong epoch or
        // a wrong degrees/radians conversion fails this test.
        let station = TideFixtures.syntheticM2Station
        let epoch = TideFixtures.date("2000-01-01T00:00:00Z")
        XCTAssertEqual(
            predictor.height(for: station, at: epoch),
            station.meanSeaLevel + 2.5,
            accuracy: 1e-9)

        // A quarter of the M2 period later the cosine is 0, so the height is Z0.
        let quarterPeriod = TideFixtures.date("2000-01-01T03:06:18Z")
        XCTAssertEqual(
            predictor.height(for: station, at: quarterPeriod),
            station.meanSeaLevel,
            accuracy: 1e-3)
    }

    func testHeightAtM2MaximumAndMinimum() {
        let station = TideFixtures.syntheticM2Station
        // Any 48-hour window of an M2-only curve contains exact highs and lows.
        let middle = TideFixtures.date("2025-06-01T00:00:00Z")
        let events = predictor.extrema(
            for: station,
            from: middle.addingTimeInterval(-24 * 3600),
            to: middle.addingTimeInterval(24 * 3600))
        let maxima = events.filter { $0.kind == .high }
        let minima = events.filter { $0.kind == .low }
        XCTAssertFalse(maxima.isEmpty, "expected at least one high in a 48 h window")
        XCTAssertFalse(minima.isEmpty, "expected at least one low in a 48 h window")
        for maximum in maxima {
            XCTAssertEqual(maximum.height, station.meanSeaLevel + 2.5, accuracy: 1e-6)
        }
        for minimum in minima {
            XCTAssertEqual(minimum.height, station.meanSeaLevel - 2.5, accuracy: 1e-6)
        }
    }

    func testMixedStationMatchesIndependentReference() {
        // Reference heights computed by a separate implementation (Python,
        // Unix-timestamp time base) from the same synthetic constants. This
        // cross-checks the epoch, the hours/degrees/radians conversions and the
        // constituent sum, independently of the Swift code under test.
        let station = TideFixtures.syntheticMixedStation
        let references: [(String, Double)] = [
            ("2026-01-15T00:00:00Z", -0.246_550_253_584_080_92),
            ("2026-04-01T12:34:56Z", -0.092_781_819_449_518_01),
            ("2026-07-01T06:00:00Z", 1.672_360_722_758_824_2),
            ("2026-10-26T18:00:00Z", 2.293_348_253_909_802_5)
        ]
        for (iso, expected) in references {
            let height = predictor.height(for: station, at: TideFixtures.date(iso))
            XCTAssertEqual(height, expected, accuracy: 1e-9, iso)
        }
    }

    // MARK: M2 period

    func testM2PeriodBetweenConsecutiveHighs() {
        let station = TideFixtures.syntheticM2Station
        let start = TideFixtures.date("2025-06-01T00:00:00Z")
        let events = predictor.extrema(
            for: station,
            from: start.addingTimeInterval(-24 * 3600),
            to: start.addingTimeInterval(48 * 3600))
        let maxima = events.filter { $0.kind == .high }
        XCTAssertGreaterThanOrEqual(maxima.count, 2, "need two consecutive highs")
        let period = maxima[1].time.timeIntervalSince(maxima[0].time)
        let expected = TideFixtures.m2PeriodHours * 3600
        XCTAssertEqual(period, expected, accuracy: 60)
    }

    // MARK: Monotonic rise

    func testHeightIsMonotonicBetweenLowAndNextHigh() {
        let station = TideFixtures.syntheticM2Station
        let middle = TideFixtures.date("2025-06-01T04:00:00Z")
        let events = predictor.extrema(
            for: station,
            from: middle.addingTimeInterval(-24 * 3600),
            to: middle.addingTimeInterval(24 * 3600))

        guard let lowIndex = events.firstIndex(where: { $0.kind == .low }) else {
            return XCTFail("expected at least one low in a 48 h window")
        }
        let highIndex = highIndexAfter(lowIndex: lowIndex, in: events)
        guard let highIndex else {
            return XCTFail("expected a high immediately after the low at index \(lowIndex)")
        }
        let low = events[lowIndex]
        let high = events[highIndex]
        XCTAssertGreaterThan(high.time.timeIntervalSince(low.time), 0)

        let stepCount = 50
        var previousHeight = low.height
        for step in 1 ... stepCount {
            let fraction = Double(step) / Double(stepCount)
            let time = low.time.addingTimeInterval(
                fraction * high.time.timeIntervalSince(low.time))
            let height = predictor.height(for: station, at: time)
            XCTAssertGreaterThanOrEqual(
                height, previousHeight - 1e-12,
                "height must not decrease while rising from low to high")
            previousHeight = height
        }
    }

    // MARK: Monotonic rise helpers

    /// Index of the event right after `lowIndex` when it is a high, else `nil`.
    private func highIndexAfter(lowIndex: Int, in events: [TideEvent]) -> Int? {
        let candidate = lowIndex + 1
        guard candidate < events.count, events[candidate].kind == .high else { return nil }
        return candidate
    }

    // MARK: Extrema structure and count

    func testExtremaAlternateAndCountOver24Hours() throws {
        let station = TideFixtures.syntheticM2Station
        // Window opening 1 hour before a known maximum (hours offset = a
        // multiple of the M2 period minus 1 h), so every extremum of the
        // window lines up exactly and none sits on a boundary sample.
        let start = TideFixtures.date(hoursAfterModelEpoch: TideFixtures.m2PeriodHours * 100 - 1)
        let end = start.addingTimeInterval(24 * 3600)
        let events = predictor.extrema(for: station, from: start, to: end)

        // Extrema are one every half M2 period, hence 3 or 4 in 24 h; starting
        // exactly on a maximum gives exactly 4 in this window.
        XCTAssertEqual(events.count, 4)

        let first = try XCTUnwrap(events.first)
        let last = try XCTUnwrap(events.last)
        XCTAssertEqual(first.kind, .high)
        XCTAssertGreaterThanOrEqual(first.time, start)
        XCTAssertLessThanOrEqual(last.time, end)
        for (previous, next) in zip(events, events.dropFirst()) {
            XCTAssertNotEqual(previous.kind, next.kind, "extrema must alternate")
            XCTAssertLessThan(previous.time, next.time, "extrema must be sorted by time")
        }
    }

    // MARK: Tide coefficient

    func testCoefficientFollowsDocumentedFormula() {
        let station = TideFixtures.syntheticM2Station
        // M2-only curve: every full UTC day holds a max and a min, so the day
        // range is exactly (Z0+H) − (Z0−H) = 5.0 m and
        // C = round(5.0 / 5.0 · 100) = 100.
        let date = TideFixtures.date("2025-06-01T12:00:00Z")
        XCTAssertEqual(predictor.coefficient(for: station, on: date), 100)
    }

    func testCoefficientIsClamped() {
        let date = TideFixtures.date("2025-06-01T12:00:00Z")
        // Raw 5.0 / 40.0 · 100 = 12.5 → clamped to 20.
        XCTAssertEqual(
            predictor.coefficient(for: TideFixtures.syntheticWideRangeStation, on: date), 20)
        // Raw 5.0 / 3.0 · 100 ≈ 167 → clamped to 120.
        XCTAssertEqual(
            predictor.coefficient(for: TideFixtures.syntheticNarrowRangeStation, on: date), 120)
    }

    func testNationalCoefficientUsesTheConventionalDivisor() {
        let station = TideFixtures.syntheticM2Station
        let date = TideFixtures.date("2025-06-01T12:00:00Z")
        // Local proxy: 5.0 / 5.0 · 100 = 100.
        XCTAssertEqual(predictor.coefficient(for: station, on: date), 100)
        // National: 5.0 / 6.10 · 100 = 81.97 → 82. Using the fitted mean spring
        // range would read +18 % high at this fixture (review Z23).
        XCTAssertEqual(predictor.nationalCoefficient(for: station, on: date), 82)
    }

    func testEngineResolvesTheCoefficientReferenceStation() async throws {
        let engine = try TideEngine(
            stations: [TideFixtures.syntheticMixedStation, TideFixtures.syntheticM2Station],
            coefficientStationID: "synthetic-m2",
            coefficientValidated: false)
        let state = try await engine.state(
            for: "synthetic-mixed",
            at: TideFixtures.date("2025-06-01T12:00:00Z"))

        XCTAssertEqual(state.coefficientSource, .nationalBrest)
        XCTAssertEqual(state.coefficient, 82)
        XCTAssertFalse(state.coefficientValidated)
    }

    func testEngineRejectsAnUnknownCoefficientStation() {
        XCTAssertThrowsError(
            try TideEngine(
                stations: [TideFixtures.syntheticM2Station],
                coefficientStationID: "missing"))
    }

    // MARK: Engine state

    private func makeEngine(stations: [TidalStation]) async throws -> TideEngine {
        try TideEngine(stations: stations)
    }

    func testStateCurveCoversExactly24Hours() async throws {
        let station = TideFixtures.syntheticM2Station
        let engine = try await makeEngine(stations: [station])
        let date = TideFixtures.date("2025-06-01T14:37:22Z")
        let state = try await engine.state(for: station, at: date)

        XCTAssertEqual(state.curve.count, 144, "a 24 h day sampled every 10 min has 144 points")

        let calendar = Calendar(identifier: .gregorian)
        var utcCalendar = calendar
        utcCalendar.timeZone = station.timezone
        let dayStart = utcCalendar.startOfDay(for: date)
        XCTAssertEqual(state.curve.first?.time, dayStart, "curve must start at local midnight")
        XCTAssertEqual(state.curve.last?.time, dayStart.addingTimeInterval(23 * 60 * 60 + 50 * 60))
        for (previous, next) in zip(state.curve, state.curve.dropFirst()) {
            XCTAssertLessThan(previous.time, next.time, "curve must be sorted by time")
        }
        for point in state.curve {
            XCTAssertEqual(point.height, predictor.height(for: station, at: point.time), accuracy: 1e-12)
        }
    }

    func testStateCurrentAndNextBracketTheDate() async throws {
        let station = TideFixtures.syntheticM2Station
        let engine = try await makeEngine(stations: [station])
        let date = TideFixtures.date("2025-06-01T09:15:00Z")
        let state = try await engine.state(for: station, at: date)

        if let current = state.current, let next = state.next {
            XCTAssertLessThanOrEqual(current.time, date, "current must be at or before date")
            XCTAssertGreaterThan(next.time, date, "next must be strictly after date")
            XCTAssertNotEqual(current.kind, next.kind, "adjacent extrema must alternate")
        } else {
            XCTFail("expected both current and next in a ±12 h window around the day")
        }
    }

    func testUnknownStationThrows() async throws {
        let engine = try await makeEngine(stations: [TideFixtures.syntheticM2Station])
        do {
            _ = try await engine.state(
                for: "unknown-id",
                at: TideFixtures.date("2025-06-01T00:00:00Z"))
            XCTFail("expected an unknownStation error")
        } catch let error as TideError {
            XCTAssertEqual(error, .unknownStation("unknown-id"))
        }
        let unknown = await engine.station(id: "unknown-id")
        XCTAssertNil(unknown)
        let known = await engine.station(id: TideFixtures.syntheticM2Station.id)
        XCTAssertNotNil(known)
        let count = await engine.allStations().count
        XCTAssertEqual(count, 1)
    }

    func testInvalidStationThrowsFromInitializer() async throws {
        do {
            _ = try await makeEngine(stations: [TideFixtures.syntheticM2Station, TideFixtures.syntheticInvalidStation])
            XCTFail("expected an invalidStation error")
        } catch let error as TideError {
            XCTAssertEqual(error, .invalidStation("amplitude must be finite and non-negative for M2"))
        }
    }

    func testDuplicateStationIdentifierThrows() async throws {
        let station = TideFixtures.syntheticM2Station
        do {
            _ = try await makeEngine(stations: [station, station])
            XCTFail("expected an invalidStation error for the duplicate id")
        } catch let error as TideError {
            XCTAssertEqual(error, .invalidStation("duplicate station id \(station.id)"))
        }
    }

    func testSingleStationIsStoredOnce() async throws {
        let station = TideFixtures.syntheticM2Station
        let engine = try await makeEngine(stations: [station])
        let stored = await engine.station(id: station.id)
        XCTAssertNotNil(stored)
        let count = await engine.allStations().count
        XCTAssertEqual(count, 1, "a duplicate id must not create two entries")
    }

    func testStateThrowsForInvalidStationArgument() async throws {
        let engine = try await makeEngine(stations: [TideFixtures.syntheticM2Station])
        do {
            _ = try await engine.state(
                for: TideFixtures.syntheticInvalidStation,
                at: TideFixtures.date("2025-06-01T00:00:00Z"))
            XCTFail("expected an invalidStation error")
        } catch let error as TideError {
            XCTAssertEqual(error, .invalidStation("amplitude must be finite and non-negative for M2"))
        }
    }

    func testStateIsDeterministic() async throws {
        let station = TideFixtures.syntheticM2Station
        let engine = try await makeEngine(stations: [station])
        let date = TideFixtures.date("2025-06-01T09:15:00Z")
        let first = try await engine.state(for: station, at: date)
        let second = try await engine.state(for: station, at: date)
        XCTAssertEqual(first, second, "the same station and date must yield an equal state")

        let byIdentifier = try await engine.state(for: station.id, at: date)
        XCTAssertEqual(byIdentifier, first)
    }
}
