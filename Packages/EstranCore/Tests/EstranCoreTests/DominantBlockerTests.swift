@testable import EstranCore
import XCTest

/// The dominant blocker that explains a windowless 48 h horizon.
final class DominantBlockerTests: XCTestCase {
    private let start = DecisionFixtures.date("2026-06-21T08:00:00Z")
    private let step: TimeInterval = 60 * 60

    private func forecast(count: Int) -> [Conditions] {
        (0 ..< count).map { index in
            let at = start.addingTimeInterval(Double(index) * step)
            return DecisionFixtures.conditions(
                at: at,
                tide: DecisionFixtures.tide(at: at, coefficient: 95))
        }
    }

    func testNightOnlyReturnsNight() {
        let blocker = WindowScanner.dominantBlocker(
            in: forecast(count: 3),
            blockers: { _ in [.night] })
        XCTAssertEqual(blocker, .night)
    }

    func testCoefficientOnlyReturnsCoefficient() {
        let blocker = WindowScanner.dominantBlocker(
            in: forecast(count: 3),
            blockers: { _ in [.coefficient] })
        XCTAssertEqual(blocker, .coefficient)
    }

    func testMixedReturnsTheMostFrequent() {
        var index = 0
        let blocker = WindowScanner.dominantBlocker(
            in: forecast(count: 3),
            blockers: { _ in
                defer { index += 1 }
                // Two coefficients, one night: the coefficient dominates.
                return index < 2 ? [.coefficient] : [.night]
            })
        XCTAssertEqual(blocker, .coefficient)
    }

    func testEmptyForecastReturnsNil() {
        let blocker = WindowScanner.dominantBlocker(
            in: [],
            blockers: { _ in [.night] })
        XCTAssertNil(blocker)
    }

    func testAllClearSamplesReturnNil() {
        let blocker = WindowScanner.dominantBlocker(
            in: forecast(count: 3),
            blockers: { _ in [] })
        XCTAssertNil(blocker)
    }

    func testEngineReportsTheCoefficientAsTheDominantBlocker() {
        // A whole forecast below the national threshold: every sample carries
        // `.coefficient`, so it must dominate over the intermittent tide-timing
        // blocker.
        let low = (0 ..< 48).map { index in
            DecisionFixtures.conditions(
                at: start.addingTimeInterval(Double(index) * step),
                tide: DecisionFixtures.tide(at: start.addingTimeInterval(Double(index) * step), coefficient: 60))
        }
        let blocker = DecisionEngine().dominantBlocker(activity: .shoreFishing, over: low)
        XCTAssertEqual(blocker, .coefficient)
    }
}
