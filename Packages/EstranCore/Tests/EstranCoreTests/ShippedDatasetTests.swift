@testable import EstranCore
import XCTest

/// Integration gate for the **shipped** dataset (`tide-model-2026.1.json`).
///
/// The synthetic fixtures in `TideModelLoaderTests` prove the contract; this
/// suite proves that the real file produced by `scripts/tides/refresh` actually
/// satisfies it and still reproduces REFMAR observations. A regeneration that
/// breaks the catalog, the horizon or the accuracy shows up here.
final class ShippedDatasetTests: XCTestCase {
    private func model() throws -> TideModel {
        try ShippedTideModel.load()
    }

    func testShippedDatasetSatisfiesTheV1Contract() throws {
        let model = try model()
        XCTAssertNil(model.validationError)
        XCTAssertEqual(model.schemaVersion, 6)
        XCTAssertFalse(model.official)
        XCTAssertTrue(model.stations.allSatisfy { !$0.nodalCorrections })

        // Keys the Swift model ignores but the data contract requires.
        let raw = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: ShippedTideModel.data()) as? [String: Any])
        XCTAssertEqual(raw["nodalCorrections"] as? Bool, false)
        XCTAssertEqual((raw["droppedConstituents"] as? [String])?.isEmpty, true)
        XCTAssertEqual(raw["epoch"] as? String, "2000-01-01T00:00:00Z")
        XCTAssertEqual(raw["datum"] as? String, "zero_hydrographique")

        XCTAssertEqual(Set(model.stations.map(\.id)), ["190", "15", "3"])
        XCTAssertEqual(model.spots.count, 2, "v1 ships exactly two spots (D3 = Option A)")
        XCTAssertEqual(Set(model.spots.map(\.validation)), [.gauged])
        XCTAssertEqual(Set(model.spots.map(\.correctionStatus)), [.none])
        XCTAssertEqual(Set(model.spots.map(\.stationId)), ["190", "15"])
    }

    func testShippedSpotsUseThePerStationEnvelope() throws {
        let model = try model()
        let envelopes = Dictionary(
            uniqueKeysWithValues: model.spots.map {
                ($0.id, $0.uncertainty)
            })
        XCTAssertEqual(envelopes["pointe-de-grave"]?.timeMinutes, 75)
        XCTAssertEqual(envelopes["pointe-de-grave"]?.heightMeters, 0.60)
        XCTAssertEqual(envelopes["arcachon-eyrac"]?.timeMinutes, 70)
        XCTAssertEqual(envelopes["arcachon-eyrac"]?.heightMeters, 0.70)
        XCTAssertTrue(envelopes.values.allSatisfy(\.isActive))
    }

    func testShippedCoefficientIsNationalButNotValidated() async throws {
        let model = try model()
        let coefficient = try XCTUnwrap(model.coefficient)
        XCTAssertEqual(coefficient.stationId, "3")
        XCTAssertEqual(coefficient.divisor, 6.10, accuracy: 0.0001)
        XCTAssertFalse(coefficient.validated, "baignade must stay dataUnavailable (Z23)")

        let engine = try model.engine()
        let state = try await engine.state(for: "190", at: Date())
        XCTAssertEqual(state.coefficientSource, .nationalBrest)
        XCTAssertFalse(state.coefficientValidated)
    }

    func testShippedSwimmingRangeIsCalibrated() throws {
        let model = try model()
        let ranges = Dictionary(
            uniqueKeysWithValues: model.spots.compactMap { spot in
                spot.swimmingRange.map { (spot.id, $0) }
            })
        XCTAssertEqual(ranges.count, model.spots.count, "every spot needs a range")
        XCTAssertEqual(ranges["arcachon-eyrac"]?.lowBelow, 3.58)
        XCTAssertEqual(ranges["arcachon-eyrac"]?.strongAt, 4.18)
        XCTAssertEqual(ranges["pointe-de-grave"]?.lowBelow, 4.03)
        XCTAssertEqual(ranges["pointe-de-grave"]?.strongAt, 4.63)
        XCTAssertTrue(ranges.values.allSatisfy(\.isValid))
    }

    func testShippedAccuracyPublishesTheOneSidedHeightBound() throws {
        let raw = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: ShippedTideModel.data()) as? [String: Any])
        let stations = try XCTUnwrap(raw["stations"] as? [[String: Any]])
        let station190 = try XCTUnwrap(stations.first { $0["id"] as? String == "190" })
        let accuracy = try XCTUnwrap(station190["accuracy"] as? [String: Any])
        let under = try XCTUnwrap(accuracy["maxUnderPredictionMeters"] as? Double)
        XCTAssertLessThanOrEqual(under, 0.65, "u_h = 0.70 must leave 0.05 m of margin")
        XCTAssertNotNil(accuracy["minOverPredictionMeters"])
        XCTAssertEqual(accuracy["samples"] as? Int, 8760, "Z20: the held-out year is complete")

        // Z27: the envelope is sized on the leave-one-year-out maximum, not on
        // the single neutral 2025 year.
        let loyo = try XCTUnwrap(accuracy["leaveOneYearOut"] as? [[String: Any]])
        XCTAssertFalse(loyo.isEmpty)
        let worst = try XCTUnwrap(
            loyo.compactMap { $0["maxUnderPredictionMeters"] as? Double }.max())
        XCTAssertLessThanOrEqual(worst, 0.65, "u_h = 0.70 must cover the worst LOYO year")
    }

    func testShippedTimeEnvelopeCoversTheWorstLOYOYear() throws {
        let raw = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: ShippedTideModel.data()) as? [String: Any])
        let stations = try XCTUnwrap(raw["stations"] as? [[String: Any]])
        let cases: [(id: String, u_t: Double)] = [("190", 70), ("15", 75)]
        for testCase in cases {
            let station = try XCTUnwrap(
                stations.first { $0["id"] as? String == testCase.id })
            let accuracy = try XCTUnwrap(station["accuracy"] as? [String: Any])
            let loyo = try XCTUnwrap(accuracy["leaveOneYearOut"] as? [[String: Any]])
            let worst = try XCTUnwrap(loyo.compactMap { entry -> Double? in
                guard let extrema = entry["extrema"] as? [String: Any],
                      let low = extrema["low"] as? [String: Any],
                      let high = extrema["high"] as? [String: Any]
                else {
                    return nil
                }
                let lowMax = low["maxMinutes"] as? Double ?? 0
                let highMax = high["maxMinutes"] as? Double ?? 0
                return max(lowMax, highMax)
            }.max())
            XCTAssertLessThanOrEqual(
                worst, testCase.u_t - 10,
                "u_t(\(testCase.id)) must cover the worst LOYO |dt| + 10 min")
        }
    }

    func testShippedStationsDeclareAHorizonThatHasNotExpired() throws {
        let model = try model()
        let now = Date()
        for station in model.stations {
            let horizon = try XCTUnwrap(station.validUntil, "station \(station.id)")
            XCTAssertGreaterThan(
                horizon, now,
                "station \(station.id) expired on \(horizon); regenerate the dataset")
            // Z28: three-year horizon for every station, not a product expiry.
            let year = Calendar(identifier: .gregorian).component(.year, from: horizon)
            XCTAssertEqual(year, 2029, "station \(station.id) horizon must be 2029")
        }
    }

    func testShippedMeanSpringRangeFollowsTheM2PlusS2Rule() throws {
        let model = try model()
        for station in model.stations {
            let derived = try XCTUnwrap(station.tidalStation.derivedMeanSpringRange)
            XCTAssertEqual(
                derived, station.meanSpringRange, accuracy: 0.01,
                "station \(station.id) must publish 2 * (M2 + S2)")
        }
    }

    /// REFMAR station 190, validated hourly source 4, held-out year 2025.
    ///
    /// The tolerance is the published p95 height error of the model (0.32 m) with
    /// a small margin, not a per-sample claim.
    func testShippedModelReproducesKnownRefmarObservations() throws {
        let model = try model()
        let station = try XCTUnwrap(model.tidalStations.first { $0.id == "190" })
        let predictor = HarmonicPredictor()

        let cases: [(date: String, observed: Double)] = [
            ("2025-06-15T18:00:00Z", 3.647),
            ("2025-06-15T12:00:00Z", 1.092),
            ("2025-06-15T06:00:00Z", 3.551)
        ]
        for testCase in cases {
            let height = predictor.height(
                for: station, at: TideFixtures.date(testCase.date))
            XCTAssertEqual(
                height, testCase.observed, accuracy: 0.35,
                "REFMAR \(testCase.date) at station 190")
        }
    }

    func testShippedEngineRefusesDatesPastTheHorizon() async throws {
        let model = try model()
        let engine = try model.engine()
        let station = try XCTUnwrap(model.tidalStations.first { $0.id == "190" })
        let horizon = try XCTUnwrap(station.validUntil)
        let beyond = horizon.addingTimeInterval(24 * 3600)
        do {
            _ = try await engine.state(for: "190", at: beyond)
            XCTFail("expected an outsideValidity error")
        } catch let error as TideError {
            XCTAssertEqual(error, .outsideValidity("190"))
        }
    }
}
