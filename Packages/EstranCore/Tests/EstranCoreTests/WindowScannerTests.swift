@testable import EstranCore
import XCTest

final class WindowScannerTests: XCTestCase {
    private let start = DecisionFixtures.date("2026-06-21T08:00:00Z")
    private let step: TimeInterval = 30 * 60

    private func forecast(count: Int, step: TimeInterval? = nil) -> [Conditions] {
        let interval = step ?? self.step
        return (0 ..< count).map { index in
            let at = start.addingTimeInterval(Double(index) * interval)
            return DecisionFixtures.conditions(at: at, tide: DecisionFixtures.tide(at: at))
        }
    }

    private func good(_ indices: Set<Int>) -> (Conditions) -> Bool {
        { conditions in
            let index = Int(conditions.at.timeIntervalSince(self.start) / self.step)
            return indices.contains(index)
        }
    }

    func testTwoConsecutiveSamplesMakeOneHour() {
        let window = WindowScanner.firstWindow(
            in: forecast(count: 8),
            after: start,
            isGood: good([2, 3]))
        XCTAssertEqual(window?.start, start.addingTimeInterval(60 * 60))
        XCTAssertEqual(window?.end, start.addingTimeInterval(120 * 60))
    }

    func testSingleSampleIsTooShort() {
        let window = WindowScanner.firstWindow(
            in: forecast(count: 8),
            after: start,
            isGood: good([2]))
        XCTAssertNil(window)
    }

    func testLongRunKeepsItsFullExtent() {
        let window = WindowScanner.firstWindow(
            in: forecast(count: 8),
            after: start,
            isGood: good([2, 3, 4, 5]))
        XCTAssertEqual(window?.start, start.addingTimeInterval(60 * 60))
        XCTAssertEqual(window?.end, start.addingTimeInterval(180 * 60))
    }

    func testGapSplitsWindows() {
        let windows = WindowScanner.allWindows(
            in: forecast(count: 10),
            after: start,
            isGood: good([2, 3, 5, 6]))
        XCTAssertEqual(windows.count, 2)
        XCTAssertEqual(windows[0].start, start.addingTimeInterval(60 * 60))
        XCTAssertEqual(windows[0].end, start.addingTimeInterval(120 * 60))
        XCTAssertEqual(windows[1].start, start.addingTimeInterval(150 * 60))
    }

    func testBlockedSampleBreaksTheRun() {
        let windows = WindowScanner.allWindows(
            in: forecast(count: 8),
            after: start,
            isGood: { conditions in
                let index = Int(conditions.at.timeIntervalSince(self.start) / self.step)
                return [2, 3, 5].contains(index)
            })
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows[0].start, start.addingTimeInterval(60 * 60))
        XCTAssertEqual(windows[0].end, start.addingTimeInterval(120 * 60))
    }

    func testRunBeforeNowIsDropped() {
        let window = WindowScanner.firstWindow(
            in: forecast(count: 8),
            after: start.addingTimeInterval(100 * 60),
            isGood: good([2, 3]))
        XCTAssertNil(window)
    }

    func testRunInProgressIsClampedToNow() {
        let now = start.addingTimeInterval(90 * 60)
        let window = WindowScanner.firstWindow(
            in: forecast(count: 8),
            after: now,
            isGood: good([2, 3, 4, 5]))
        XCTAssertEqual(window?.start, now)
        XCTAssertEqual(window?.end, start.addingTimeInterval(180 * 60))
    }

    func testHourlySeriesUsesTheInferredStep() {
        let hourly: TimeInterval = 60 * 60
        let samples = forecast(count: 6, step: hourly)
        let window = WindowScanner.firstWindow(
            in: samples,
            after: start,
            isGood: { conditions in
                let index = Int(conditions.at.timeIntervalSince(self.start) / hourly)
                return (1 ... 3).contains(index)
            })
        XCTAssertEqual(window?.start, start.addingTimeInterval(hourly))
        XCTAssertEqual(window?.end, start.addingTimeInterval(hourly * 4))
    }

    func testEmptyForecastHasNoWindow() {
        XCTAssertTrue(
            WindowScanner.allWindows(in: [], after: start, isGood: { _ in true }).isEmpty)
    }
}
