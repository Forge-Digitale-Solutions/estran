@testable import EstranCore
import XCTest

/// Strict validation of station data (review B4).
///
/// A station that cannot feed the harmonic model must be rejected at the
/// boundary instead of producing a plausible-looking but wrong tide.
final class TidalStationValidationTests: XCTestCase {
    private func station(
        timezoneIdentifier: String = "UTC",
        meanSeaLevel: Double = 2,
        meanSpringRange: Double = 5,
        coordinate: Coordinate = Coordinate(latitude: 0, longitude: 0),
        constituents: [HarmonicConstituent] = [
            HarmonicConstituent(symbol: "M2", amplitude: 2.5, phaseDegrees: 0)
        ],
        validUntil: Date? = nil,
        nodalCorrections: Bool = false) -> TidalStation
    {
        TidalStation(
            id: "validation-fixture",
            name: "Validation fixture",
            coordinate: coordinate,
            timezoneIdentifier: timezoneIdentifier,
            meanSeaLevel: meanSeaLevel,
            meanSpringRange: meanSpringRange,
            constituents: constituents,
            attribution: "Synthetic test fixture",
            validUntil: validUntil,
            nodalCorrections: nodalCorrections)
    }

    func testValidStationHasNoValidationError() {
        XCTAssertNil(station().validationError)
    }

    func testUnknownTimezoneIsRejected() {
        XCTAssertEqual(
            station(timezoneIdentifier: "Mars/Olympus").validationError,
            .invalidStation("invalid timezoneIdentifier Mars/Olympus"))
    }

    func testNonFiniteValuesAreRejected() {
        XCTAssertEqual(
            station(meanSeaLevel: .nan).validationError,
            .invalidStation("meanSeaLevel must be finite"))
        XCTAssertEqual(
            station(meanSpringRange: .infinity).validationError,
            .invalidStation("meanSpringRange must be finite and positive"))
        XCTAssertEqual(
            station(meanSpringRange: 0).validationError,
            .invalidStation("meanSpringRange must be finite and positive"))
        XCTAssertEqual(
            station(meanSpringRange: -1).validationError,
            .invalidStation("meanSpringRange must be finite and positive"))
    }

    func testNonFiniteConstituentsAreRejected() {
        XCTAssertEqual(
            station(constituents: [
                HarmonicConstituent(symbol: "M2", amplitude: .nan, phaseDegrees: 0)
            ]).validationError,
            .invalidStation("amplitude must be finite and non-negative for M2"))
        XCTAssertEqual(
            station(constituents: [
                HarmonicConstituent(symbol: "M2", amplitude: .infinity, phaseDegrees: 0)
            ]).validationError,
            .invalidStation("amplitude must be finite and non-negative for M2"))
        XCTAssertEqual(
            station(constituents: [
                HarmonicConstituent(symbol: "M2", amplitude: 1, phaseDegrees: .nan)
            ]).validationError,
            .invalidStation("phase must be finite for M2"))
    }

    func testOutOfBoundsCoordinateIsRejected() {
        XCTAssertEqual(
            station(coordinate: Coordinate(latitude: 91, longitude: 0)).validationError,
            .invalidStation("coordinate must be finite and within valid bounds"))
        XCTAssertEqual(
            station(coordinate: Coordinate(latitude: 0, longitude: 181)).validationError,
            .invalidStation("coordinate must be finite and within valid bounds"))
        XCTAssertEqual(
            station(coordinate: Coordinate(latitude: .nan, longitude: 0)).validationError,
            .invalidStation("coordinate must be finite and within valid bounds"))
    }

    func testEmptyAndUnknownConstituentsAreRejected() {
        XCTAssertEqual(
            station(constituents: []).validationError,
            .invalidStation("constituents must not be empty"))
        XCTAssertEqual(
            station(constituents: [
                HarmonicConstituent(symbol: "XYZ", amplitude: 1, phaseDegrees: 0)
            ]).validationError,
            .invalidStation("unknown constituent XYZ"))
    }

    func testDuplicateConstituentsAreRejected() {
        XCTAssertEqual(
            station(constituents: [
                HarmonicConstituent(symbol: "M2", amplitude: 1, phaseDegrees: 0),
                HarmonicConstituent(symbol: "M2", amplitude: 1, phaseDegrees: 0)
            ]).validationError,
            .invalidStation("duplicate constituent M2"))
    }

    func testCompoundAndLongPeriodConstituentsAreSupported() throws {
        let fixture = station(constituents: [
            HarmonicConstituent(symbol: "MN4", amplitude: 0.1, phaseDegrees: 0),
            HarmonicConstituent(symbol: "2Q1", amplitude: 0.1, phaseDegrees: 0),
            HarmonicConstituent(symbol: "RHO1", amplitude: 0.1, phaseDegrees: 0),
            HarmonicConstituent(symbol: "M1", amplitude: 0.1, phaseDegrees: 0)
        ])
        XCTAssertNil(fixture.validationError)
        XCTAssertEqual(
            try XCTUnwrap(ConstituentSpeeds.degreesPerHour(for: "MN4")),
            57.423_833_7,
            accuracy: 0.000_1)
        XCTAssertEqual(
            try XCTUnwrap(ConstituentSpeeds.degreesPerHour(for: "2Q1")),
            12.854_286_2,
            accuracy: 0.000_1)
        XCTAssertEqual(
            try XCTUnwrap(ConstituentSpeeds.degreesPerHour(for: "RHO1")),
            13.471_514_5,
            accuracy: 0.000_1)
        XCTAssertEqual(
            try XCTUnwrap(ConstituentSpeeds.degreesPerHour(for: "M1")),
            14.496_693_9,
            accuracy: 0.000_1)
    }

    func testEngineRejectsAnInvalidStationAtInitialisation() {
        do {
            _ = try TideEngine(stations: [station(timezoneIdentifier: "Mars/Olympus")])
            XCTFail("expected an invalidStation error")
        } catch let error as TideError {
            XCTAssertEqual(error, .invalidStation("invalid timezoneIdentifier Mars/Olympus"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testStationRejectsNodalCorrectionsTheEngineCannotApply() {
        XCTAssertEqual(
            station(nodalCorrections: true).validationError,
            .invalidStation("nodal corrections are not implemented; set nodalCorrections to false"))
    }

    func testDerivedMeanSpringRangeUsesM2AndS2() throws {
        let fixture = station(constituents: [
            HarmonicConstituent(symbol: "M2", amplitude: 1.7, phaseDegrees: 120),
            HarmonicConstituent(symbol: "S2", amplitude: 0.6, phaseDegrees: 150)
        ])
        XCTAssertEqual(try XCTUnwrap(fixture.derivedMeanSpringRange), 4.6, accuracy: 1e-12)
    }

    func testStationWithoutM2OrS2HasNoDerivedMeanSpringRange() {
        let fixture = station(constituents: [
            HarmonicConstituent(symbol: "K1", amplitude: 0.4, phaseDegrees: 90)
        ])
        XCTAssertNil(fixture.derivedMeanSpringRange)
    }
}
