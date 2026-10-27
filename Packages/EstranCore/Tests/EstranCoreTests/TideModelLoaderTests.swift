@testable import EstranCore
import XCTest

/// End-to-end dataset contract (review Z9, Z10, Z11, Z12).
///
/// The generated JSON must load into `TidalStation`/`TideEngine` without manual
/// patching, carry a validity horizon, and never expose an identity correction
/// or a misleading label as if it were validated.
final class TideModelLoaderTests: XCTestCase {
    private static let validModelJSON = """
    {
      "schemaVersion": 4,
      "source": "REFMAR / Shom",
      "license": "Licence Ouverte 2.0",
      "retrievedAt": "2026-10-26T00:00:00Z",
      "official": false,
      "stations": [
        {
          "id": "synthetic-m2",
          "name": "Synthetic M2 Station",
          "role": "test",
          "coordinate": {"latitude": 0, "longitude": 0},
          "timezoneIdentifier": "UTC",
          "meanSeaLevel": 2.0,
          "meanSpringRange": 5.0,
          "constituents": [
            {"symbol": "M2", "amplitude": 2.5, "phaseDegrees": 0}
          ],
          "validUntil": "2027-12-31T23:59:59Z",
          "nodalCorrections": false,
          "attribution": "Synthetic test fixture"
        }
      ],
      "spots": [
        {
          "id": "synthetic-spot",
          "stationId": "synthetic-m2",
          "correction": {"lagMinutes": 0, "amplitudeFactor": 1.0},
          "correctionStatus": "none",
          "validation": "gauged",
          "uncertainty": {"timeMinutes": 45, "heightMeters": 0.5}
        }
      ]
    }
    """

    private func load(_ json: String) throws -> TideModel {
        try TideModel.load(from: Data(json.utf8))
    }

    func testGeneratedJSONLoadsIntoAStationAndEngine() async throws {
        let model = try load(Self.validModelJSON)
        XCTAssertNil(model.validationError)
        XCTAssertEqual(model.tidalStations.count, 1)

        let station = try XCTUnwrap(model.tidalStations.first)
        XCTAssertEqual(station.id, "synthetic-m2")
        XCTAssertEqual(station.validUntil, TideFixtures.date("2027-12-31T23:59:59Z"))
        XCTAssertFalse(station.nodalCorrections)

        let engine = try model.engine()
        let state = try await engine.state(for: "synthetic-m2", at: TideFixtures.date("2025-06-01T00:00:00Z"))
        XCTAssertEqual(state.curve.count, 144)
        XCTAssertEqual(state.coefficient, 100)
    }

    func testEngineFailsClosedPastTheValidityHorizon() async throws {
        let model = try load(Self.validModelJSON)
        let engine = try model.engine()
        do {
            _ = try await engine.state(for: "synthetic-m2", at: TideFixtures.date("2028-01-01T00:00:00Z"))
            XCTFail("expected an outsideValidity error")
        } catch let error as TideError {
            XCTAssertEqual(error, .outsideValidity("synthetic-m2"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testDatasetWithoutHorizonIsRejected() throws {
        let json = Self.validModelJSON.replacingOccurrences(
            of: "\"validUntil\": \"2027-12-31T23:59:59Z\"",
            with: "\"validUntil\": null")
        let model = try load(json)
        XCTAssertEqual(
            model.validationError,
            .invalidStation("every station must declare validUntil"))
    }

    func testOfficialDatasetIsRejected() throws {
        let json = Self.validModelJSON.replacingOccurrences(
            of: "\"official\": false",
            with: "\"official\": true")
        let model = try load(json)
        XCTAssertEqual(
            model.validationError,
            .invalidStation("dataset must not claim official status"))
    }

    func testSpotReferencingAnUnknownStationIsRejected() throws {
        let json = Self.validModelJSON.replacingOccurrences(
            of: "\"stationId\": \"synthetic-m2\"",
            with: "\"stationId\": \"missing\"")
        let model = try load(json)
        XCTAssertEqual(
            model.validationError,
            .invalidStation("spot synthetic-spot references unknown station missing"))
    }

    // MARK: - v1 contract (review Z17)

    func testInactiveEnvelopeIsRejected() throws {
        let json = Self.validModelJSON.replacingOccurrences(
            of: "\"uncertainty\": {\"timeMinutes\": 45, \"heightMeters\": 0.5}",
            with: "\"uncertainty\": {\"timeMinutes\": 0, \"heightMeters\": 0}")
        let model = try load(json)
        XCTAssertEqual(
            model.validationError,
            .invalidStation("spot synthetic-spot has an inactive uncertainty envelope"))
    }

    func testEstimatedSpotIsRejectedByTheV1Contract() throws {
        let json = Self.validModelJSON.replacingOccurrences(
            of: "\"validation\": \"gauged\"",
            with: "\"validation\": \"estimatedOpenCoast\"")
        let model = try load(json)
        XCTAssertEqual(
            model.validationError,
            .invalidStation("spot synthetic-spot is not gauged; the v1 catalog ships gauged spots only"))
    }

    func testCorrectionOnAGaugedSpotIsRejected() throws {
        let json = Self.validModelJSON.replacingOccurrences(
            of: "\"correctionStatus\": \"none\"",
            with: "\"correctionStatus\": \"calibrated\"")
        let model = try load(json)
        XCTAssertEqual(
            model.validationError,
            .invalidStation("spot synthetic-spot declares a correction; v1 gauged spots carry none"))
    }

    func testUncalibratedIdentityCorrectionStaysDistinctFromACalibratedOne() throws {
        let model = try load(Self.validModelJSON)
        let entry = try XCTUnwrap(model.spots.first)
        XCTAssertEqual(entry.correction.lagMinutes, 0)
        XCTAssertEqual(entry.correction.amplitudeFactor, 1.0)
        XCTAssertEqual(entry.correctionStatus, .none)
        XCTAssertNotEqual(entry.correctionStatus, .calibrated)
    }

    // MARK: - Labels (Z11)

    func testSpotLabelsNeverClaimALocalMeasurementOrOfficialData() {
        let gauged = makeSpot(
            id: "gauged",
            stationID: "190",
            validation: .gauged,
            correctionStatus: .calibrated)
        let estimated = makeSpot(
            id: "estimated",
            stationID: "190",
            validation: .estimatedOpenCoast,
            correctionStatus: .none)
        let lagoon = makeSpot(
            id: "lagoon",
            stationID: "190",
            validation: .estimatedLagoon,
            correctionStatus: .estimated)

        XCTAssertEqual(gauged.modelLabel, "modèle local — station 190")
        XCTAssertEqual(estimated.modelLabel, "estimation — modèle local")
        XCTAssertEqual(lagoon.modelLabel, "estimation — modèle local")

        for label in [gauged.modelLabel, estimated.modelLabel, lagoon.modelLabel] {
            let normalized = label.lowercased()
            XCTAssertFalse(normalized.contains("mesure locale"))
            XCTAssertFalse(normalized.contains("officielle"))
            XCTAssertFalse(normalized.contains("shom"))
        }
    }

    func testAccuracyBlockMustPublishTheOneSidedBounds() {
        let station = TideModel.Station(
            id: "synthetic-m2",
            name: "Synthetic M2 Station",
            coordinate: Coordinate(latitude: 0, longitude: 0),
            timezoneIdentifier: "UTC",
            meanSeaLevel: 2,
            meanSpringRange: 5,
            constituents: [HarmonicConstituent(symbol: "M2", amplitude: 2.5, phaseDegrees: 0)],
            validUntil: Date(timeIntervalSince1970: 1_800_000_000),
            nodalCorrections: false,
            attribution: "test",
            accuracy: TideModel.Accuracy(samples: 10))
        let model = TideModel(
            schemaVersion: 6,
            source: "test",
            license: "test",
            retrievedAt: Date(timeIntervalSince1970: 0),
            official: false,
            stations: [station],
            spots: [])

        XCTAssertNotNil(
            model.validationError,
            "an accuracy block without the one-sided bounds must be rejected")
    }

    private func makeSpot(
        id: String,
        stationID: String,
        validation: SpotValidation,
        correctionStatus: CorrectionStatus) -> Spot
    {
        Spot(
            id: id,
            name: id,
            region: .bassin,
            coordinate: Coordinate(latitude: 44.66, longitude: -1.17),
            tideStation: TideStationRef(id: stationID, name: "ARCACHON_EYRAC"),
            supportedActivities: Set(Activity.allCases),
            timezone: DecisionFixtures.timezone,
            validation: validation,
            correctionStatus: correctionStatus,
            uncertainty: TideUncertainty(timeMinutes: 60, heightMeters: 0.5))
    }
}
