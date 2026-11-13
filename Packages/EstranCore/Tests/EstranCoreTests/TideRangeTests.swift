@testable import EstranCore
import XCTest

/// Tidal range (« marnage ») categories: terciles of the local daily range.
///
/// The product decision (owner, 2026-11-13) is that the national Brest
/// coefficient stays computed, unvalidated and unshown; the screen says
/// « Marnage 3,8 m · grande marée » instead, derived from the shipped local
/// model at the spot.
final class TideRangeTests: XCTestCase {
    private let predictor = HarmonicPredictor()

    // MARK: - Terciles

    func testTercilesSplitTheSampleInThreeEqualParts() {
        // 30 consecutive integer ranges: the tercile boundaries are the 10th and
        // 20th values of the ascending sample, interpolated.
        let ranges = (1 ... 30).map(Double.init)
        let thresholds = TideRangeThresholds(dailyRanges: ranges)
        XCTAssertNotNil(thresholds)
        guard let thresholds else { return }
        XCTAssertEqual(thresholds.sampleCount, 30)
        XCTAssertEqual(thresholds.neapBelow, 10.666_666, accuracy: 1e-4)
        XCTAssertEqual(thresholds.springAt, 20.333_333, accuracy: 1e-4)
        XCTAssertLessThan(thresholds.neapBelow, thresholds.springAt)
    }

    func testCategoryBoundariesAreInclusiveOnTheSpringSide() {
        let thresholds = TideRangeThresholds(neapBelow: 2.0, springAt: 3.0, sampleCount: 30)
        XCTAssertEqual(thresholds.category(for: 1.99), .neap)
        XCTAssertEqual(thresholds.category(for: 2.0), .mean)
        XCTAssertEqual(thresholds.category(for: 2.99), .mean)
        XCTAssertEqual(thresholds.category(for: 3.0), .spring)
        XCTAssertEqual(thresholds.category(for: 4.5), .spring)
    }

    func testTooFewDaysGiveNoThresholds() {
        // A single spring/neap cycle is the minimum: fewer days would let one
        // festival tide define a category.
        let ranges = (1 ..< TideRangeThresholds.minimumSamples).map(Double.init)
        XCTAssertNil(TideRangeThresholds(dailyRanges: ranges))
        XCTAssertNil(TideRangeThresholds(dailyRanges: []))
    }

    func testNonPositiveAndNonFiniteRangesAreDropped() {
        let ranges = [0, -1, .nan, .infinity] + (1 ... 20).map(Double.init)
        let thresholds = TideRangeThresholds(dailyRanges: ranges)
        XCTAssertEqual(thresholds?.sampleCount, 20)
    }

    func testFlatSampleHasNoTerciles() {
        // Every day the same range: the terciles collapse, and a category would
        // be invented by the comparison order. No thresholds then.
        let flat = Array(repeating: 3.0, count: 30)
        XCTAssertNil(TideRangeThresholds(dailyRanges: flat))
    }

    // MARK: - Daily ranges from the model

    func testSyntheticM2StationHasAConstantFiveMetreRange() {
        // `syntheticM2Station` swings ±2.5 m around a 2.0 m mean sea level every
        // day: the marnage is 5.0 m and never varies, so a tercile split would be
        // an artefact — no category is derived.
        let station = TideFixtures.syntheticM2Station
        let start = TideFixtures.date("2026-03-01T00:00:00Z")
        let ranges = TideRangeBaseline.dailyRanges(station: station, from: start, days: 20)
        XCTAssertEqual(ranges.count, 20)
        for range in ranges {
            XCTAssertEqual(range, 5.0, accuracy: 1e-3)
        }
        XCTAssertNil(
            TideRangeThresholds(dailyRanges: ranges),
            "a constant range has no terciles")
    }

    func testShippedSpotProducesUsableTerciles() throws {
        let model = try ShippedTideModel.load()
        let entry = try XCTUnwrap(model.spots.first)
        let station = try XCTUnwrap(model.stations.first { $0.id == entry.stationId }).tidalStation
        let start = try XCTUnwrap(station.validUntil).addingTimeInterval(-40 * 86400)
        let ranges = TideRangeBaseline.dailyRanges(station: station, from: start, days: 30)

        XCTAssertGreaterThanOrEqual(ranges.count, 29)
        for range in ranges {
            // The two spots live on a 1–5 m tidal range: anything outside this
            // band means the extrema pairing is wrong, not a real spring tide.
            XCTAssertGreaterThan(range, 0.5)
            XCTAssertLessThan(range, 6.0)
        }
        let thresholds = try XCTUnwrap(TideRangeThresholds(dailyRanges: ranges))
        XCTAssertLessThan(thresholds.neapBelow, thresholds.springAt)
        XCTAssertTrue(ranges.contains { thresholds.category(for: $0) == .neap })
        XCTAssertTrue(ranges.contains { thresholds.category(for: $0) == .spring })
    }

    // MARK: - The day's range

    func testDayRangeIsHighMinusLow() throws {
        let day = TideFixtures.date("2026-03-01T00:00:00Z")
        let tide = TideState(
            current: TideEvent(
                time: day.addingTimeInterval(2 * 3600), kind: .low, height: 1.2),
            next: TideEvent(
                time: day.addingTimeInterval(8 * 3600), kind: .high, height: 3.6),
            coefficient: 70,
            curve: [TidePoint(time: day.addingTimeInterval(3600), height: 1.5)],
            safetyCurve: [])
        let range = TideRangeBaseline.range(of: tide, in: TimeZone.gmt, at: day)
        XCTAssertEqual(try XCTUnwrap(range), 2.4, accuracy: 1e-9)
    }

    func testDayWithoutBothExtremaGetsNoRange() {
        // One high and no low: a half range is not a marnage, so nothing is
        // shown rather than half a number (invariant 3).
        let day = TideFixtures.date("2026-03-01T00:00:00Z")
        let tide = TideState(
            current: TideEvent(
                time: day.addingTimeInterval(8 * 3600), kind: .high, height: 3.6),
            next: nil,
            coefficient: 70,
            curve: [TidePoint(time: day.addingTimeInterval(3600), height: 1.5)],
            safetyCurve: [])
        XCTAssertNil(TideRangeBaseline.range(of: tide, in: TimeZone.gmt, at: day))
    }

    func testDayOutsideTheEventsGetsNoRange() {
        let day = TideFixtures.date("2026-03-01T00:00:00Z")
        let otherDay = day.addingTimeInterval(3 * 86400)
        let tide = TideState(
            current: TideEvent(
                time: otherDay.addingTimeInterval(2 * 3600), kind: .low, height: 1.2),
            next: TideEvent(
                time: otherDay.addingTimeInterval(8 * 3600), kind: .high, height: 3.6),
            coefficient: 70,
            curve: [],
            safetyCurve: [])
        XCTAssertNil(TideRangeBaseline.range(of: tide, in: TimeZone.gmt, at: day))
    }

    func testDayDressesTheRangeWithItsCategory() throws {
        let day = TideFixtures.date("2026-03-01T00:00:00Z")
        let tide = TideState(
            current: TideEvent(
                time: day.addingTimeInterval(2 * 3600), kind: .low, height: 0.6),
            next: TideEvent(
                time: day.addingTimeInterval(8 * 3600), kind: .high, height: 4.6),
            coefficient: 95,
            curve: [],
            safetyCurve: [])
        let thresholds = TideRangeThresholds(neapBelow: 2.0, springAt: 3.0, sampleCount: 30)
        let dressed = try XCTUnwrap(
            TideRangeBaseline.day(of: tide, in: TimeZone.gmt, at: day, thresholds: thresholds))
        XCTAssertEqual(dressed.range, 4.0, accuracy: 1e-9)
        XCTAssertEqual(dressed.category, .spring)
        XCTAssertEqual(dressed.category.label, "grande marée")
    }

    // MARK: - Wording

    func testCategoryLabelsNeverSayCoefficient() {
        for category in TideRangeCategory.allCases {
            XCTAssertFalse(category.label.lowercased().contains("coefficient"))
            XCTAssertFalse(category.label.lowercased().contains("shom"))
            XCTAssertFalse(category.label.lowercased().contains("officiel"))
        }
        XCTAssertEqual(TideRangeCategory.spring.label, "grande marée")
        XCTAssertEqual(TideRangeCategory.mean.label, "marée moyenne")
        XCTAssertEqual(TideRangeCategory.neap.label, "petite marée")
    }

    // MARK: - Cost guard

    func testShippedBaselineStaysWithinItsOffMainActorBudget() throws {
        // The terciles are computed once per spot, off the main actor, when the
        // app loads a spot. This guards the cost of that one background task
        // (a Debug build takes ~0.7 s for a full year; a release build is far
        // cheaper). If it ever grows past a couple of seconds, shorten the
        // horizon rather than moving it back onto the main actor.
        let model = try ShippedTideModel.load()
        let station = try XCTUnwrap(model.stations.first).tidalStation
        let start = try XCTUnwrap(station.validUntil)
            .addingTimeInterval(-Double(TideRangeBaseline.maximumHorizonDays + 1) * 86400)
        let began = Date()
        let thresholds = TideRangeBaseline.thresholds(station: station, from: start)
        let elapsed = Date().timeIntervalSince(began)
        XCTAssertNotNil(thresholds)
        XCTAssertLessThan(elapsed, 2.0, "the year-long baseline must stay under 2 s")
    }
}
