@testable import Estran
import EstranCore
import XCTest

/// A window range must name the day whenever it does not start and end on the
/// same local day as today, so a range crossing midnight can never read as a
/// same-day window (owner feedback 2026-11-12).
final class FrenchFormatRangeTests: XCTestCase {
    private let timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt

    private func date(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date
    {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute)
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    func testSameDayTodayStaysTimesOnly() {
        let reference = date(2026, 10, 28, 12, 0)
        let window = DateInterval(
            start: date(2026, 10, 28, 15, 30),
            end: date(2026, 10, 28, 17, 30))
        XCTAssertEqual(
            FrenchFormat.range(window, in: timeZone, reference: reference),
            "15 h 30 à 17 h 30")
    }

    func testCrossesMidnightNamesBothDays() {
        let reference = date(2026, 10, 28, 12, 0)
        let window = DateInterval(
            start: date(2026, 10, 28, 19, 21),
            end: date(2026, 10, 29, 17, 21))
        XCTAssertEqual(
            FrenchFormat.range(window, in: timeZone, reference: reference),
            "ce soir 19 h 21 → demain 17 h 21")
    }

    func testStartsTomorrowSameDay() {
        let reference = date(2026, 10, 28, 12, 0)
        let window = DateInterval(
            start: date(2026, 10, 29, 8, 30),
            end: date(2026, 10, 29, 10, 30))
        XCTAssertEqual(
            FrenchFormat.range(window, in: timeZone, reference: reference),
            "demain 8 h 30 à 10 h 30")
    }

    func testStartsAfterTomorrow() {
        let reference = date(2026, 10, 28, 12, 0)
        let window = DateInterval(
            start: date(2026, 10, 30, 8, 30),
            end: date(2026, 10, 30, 10, 30))
        XCTAssertEqual(
            FrenchFormat.range(window, in: timeZone, reference: reference),
            "après-demain 8 h 30 à 10 h 30")
    }

    func testAroundSpringForward() {
        // Europe/Paris springs forward on 2026-03-29 (02:00 → 03:00).
        let reference = date(2026, 3, 28, 12, 0)
        let window = DateInterval(
            start: date(2026, 3, 29, 8, 30),
            end: date(2026, 3, 29, 10, 30))
        XCTAssertEqual(
            FrenchFormat.range(window, in: timeZone, reference: reference),
            "demain 8 h 30 à 10 h 30")
    }

    func testAroundFallBack() {
        // Europe/Paris falls back on 2026-10-25 (03:00 → 02:00).
        let reference = date(2026, 10, 24, 12, 0)
        let window = DateInterval(
            start: date(2026, 10, 25, 8, 30),
            end: date(2026, 10, 25, 10, 30))
        XCTAssertEqual(
            FrenchFormat.range(window, in: timeZone, reference: reference),
            "demain 8 h 30 à 10 h 30")
    }
}
