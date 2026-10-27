@testable import EstranCore
import XCTest

final class TideStateHelpersTests: XCTestCase {
    private let reference = DecisionFixtures.date("2026-06-21T10:00:00Z")

    func testProgressAndDirection() {
        let tide = DecisionFixtures.tide(
            at: reference,
            currentKind: .low,
            minutesSinceCurrent: 120,
            minutesToNext: 240)
        XCTAssertEqual(tide.isRising, true)
        XCTAssertEqual(tide.progress(at: reference) ?? -1, 1.0 / 3.0, accuracy: 1e-12)
        XCTAssertNil(tide.progress(at: reference.addingTimeInterval(-3 * 3600)))
    }

    func testFallingTide() {
        let tide = DecisionFixtures.tide(
            at: reference,
            currentKind: .high,
            currentHeight: 4.4,
            nextKind: .low,
            nextHeight: 0.4)
        XCTAssertEqual(tide.isRising, false)
    }

    func testNearestLowWater() {
        let tide = DecisionFixtures.tide(at: reference, minutesSinceCurrent: 40)
        XCTAssertEqual(tide.minutesFromNearestEvent(of: .low, to: reference) ?? -1, 40, accuracy: 1e-12)
        XCTAssertEqual(tide.nearestEvent(of: .high, to: reference)?.time, tide.next?.time)

        let noLow = TideState(
            current: TideEvent(time: reference, kind: .high, height: 4),
            next: nil,
            coefficient: 90,
            curve: [])
        XCTAssertNil(noLow.minutesFromNearestEvent(of: .low, to: reference))
    }

    func testHeightInterpolatesTheCurve() {
        let tide = DecisionFixtures.tide(
            at: reference,
            currentHeight: 1,
            nextHeight: 3,
            minutesSinceCurrent: 0,
            minutesToNext: 120)
        XCTAssertEqual(tide.height(at: reference) ?? -1, 1, accuracy: 1e-12)
        XCTAssertEqual(
            tide.height(at: reference.addingTimeInterval(60 * 60)) ?? -1,
            2,
            accuracy: 1e-12)
        XCTAssertNil(tide.height(at: reference.addingTimeInterval(-5 * 3600)))
    }

    func testSlackWindow() {
        let tide = DecisionFixtures.tide(at: reference, minutesSinceCurrent: 5)
        XCTAssertTrue(tide.isSlack(at: reference))
        XCTAssertFalse(tide.isSlack(at: reference.addingTimeInterval(60 * 60)))
    }
}
