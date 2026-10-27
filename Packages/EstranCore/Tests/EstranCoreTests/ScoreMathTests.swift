@testable import EstranCore
import XCTest

final class ScoreMathTests: XCTestCase {
    func testClamp() {
        XCTAssertEqual(ScoreMath.clamp(-1), 0)
        XCTAssertEqual(ScoreMath.clamp(0.4), 0.4)
        XCTAssertEqual(ScoreMath.clamp(3), 1)
    }

    func testLinearRampInBothDirections() {
        XCTAssertEqual(ScoreMath.linear(50, zeroAt: 50, fullAt: 70), 0)
        XCTAssertEqual(ScoreMath.linear(70, zeroAt: 50, fullAt: 70), 1)
        XCTAssertEqual(ScoreMath.linear(60, zeroAt: 50, fullAt: 70), 0.5, accuracy: 1e-12)

        XCTAssertEqual(ScoreMath.linear(30, zeroAt: 30, fullAt: 15), 0)
        XCTAssertEqual(ScoreMath.linear(15, zeroAt: 30, fullAt: 15), 1)
        XCTAssertEqual(ScoreMath.linear(22.5, zeroAt: 30, fullAt: 15), 0.5, accuracy: 1e-12)
    }

    func testLinearClampsOutsideTheRamp() {
        XCTAssertEqual(ScoreMath.linear(-10, zeroAt: 0, fullAt: 10), 0)
        XCTAssertEqual(ScoreMath.linear(30, zeroAt: 0, fullAt: 10), 1)
    }

    func testTrapezoid() {
        let full = 8.0 ... 30.0
        let zero = -2.0 ... 38.0
        XCTAssertEqual(ScoreMath.trapezoid(20, full: full, zero: zero), 1)
        XCTAssertEqual(ScoreMath.trapezoid(-2, full: full, zero: zero), 0)
        XCTAssertEqual(ScoreMath.trapezoid(38, full: full, zero: zero), 0)
        XCTAssertEqual(ScoreMath.trapezoid(-40, full: full, zero: zero), 0)
        XCTAssertEqual(ScoreMath.trapezoid(3, full: full, zero: zero), 0.5, accuracy: 1e-12)
        XCTAssertEqual(ScoreMath.trapezoid(34, full: full, zero: zero), 0.5, accuracy: 1e-12)
    }

    func testWeightedMean() {
        XCTAssertEqual(ScoreMath.weighted([(1, 0.5), (0, 0.5)]), 0.5, accuracy: 1e-12)
        XCTAssertEqual(ScoreMath.weighted([(1, 2), (0, 1)]), 2.0 / 3.0, accuracy: 1e-12)
        XCTAssertEqual(ScoreMath.weighted([]), 0)
    }

    func testAngularDistanceWrapsAtNorth() {
        XCTAssertEqual(ScoreMath.angularDistance(350, 10), 20, accuracy: 1e-12)
        XCTAssertEqual(ScoreMath.angularDistance(10, 350), 20, accuracy: 1e-12)
        XCTAssertEqual(ScoreMath.angularDistance(0, 180), 180, accuracy: 1e-12)
        XCTAssertEqual(ScoreMath.angularDistance(90, 90), 0, accuracy: 1e-12)
    }

    func testOnshoreComponent() {
        // Coast faces west (270). Wind from west is onshore, from east offshore.
        XCTAssertEqual(ScoreMath.onshoreComponent(windDirection: 270, coastOrientation: 270), 1, accuracy: 1e-12)
        XCTAssertEqual(ScoreMath.onshoreComponent(windDirection: 90, coastOrientation: 270), -1, accuracy: 1e-12)
        XCTAssertEqual(ScoreMath.onshoreComponent(windDirection: 0, coastOrientation: 270), 0, accuracy: 1e-12)
    }
}
