@testable import Estran
import EstranCore
import Foundation
import XCTest

/// The notification rules: which windows ring, when, in which words, and what
/// the adapter does with the sample flag and the pending requests it owns.
final class NotificationPolicyTests: XCTestCase {
    private let timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt

    private static let hour: TimeInterval = 60 * 60

    // MARK: - Fixtures

    /// A fixed June instant, so the local wall clock cannot shift with the run.
    private func date(_ hour: Int, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 15,
            hour: hour,
            minute: minute)) ?? Date(timeIntervalSince1970: 0)
    }

    private func slot(
        start: Date,
        duration: TimeInterval = 2 * 60 * 60,
        activity: Activity = .shoreFishing) -> ActivitySlot
    {
        ActivitySlot(
            activity: activity,
            window: DateInterval(start: start, duration: duration),
            score: 0.8,
            go: true)
    }

    private func input(
        windows: [ActivitySlot],
        now: Date,
        activity: Activity = .shoreFishing,
        alertsEnabled: Bool = true) -> NotificationPolicy.Input
    {
        NotificationPolicy.Input(
            windows: windows,
            spotID: "arcachon-eyrac",
            spotName: "Arcachon-Eyrac",
            activity: activity,
            timeZone: timeZone,
            alertsEnabled: alertsEnabled,
            now: now)
    }

    // MARK: - Lead time

    func testTheNotificationFiresOneHourBeforeTheWindow() throws {
        let start = date(13, 10)
        let plan = NotificationPolicy.plan(input(windows: [slot(start: start)], now: date(10)))

        let notification = try XCTUnwrap(plan.first)
        XCTAssertEqual(plan.count, 1)
        XCTAssertEqual(notification.fireDate, start.addingTimeInterval(-Self.hour))
    }

    func testAWindowAlreadyRunningIsNotScheduled() {
        // Fire time was at 11:30, the reference instant is noon.
        let plan = NotificationPolicy.plan(
            input(windows: [slot(start: date(12, 30))], now: date(12)))

        XCTAssertTrue(plan.isEmpty, "a notification that arrives after the moment is noise")
    }

    func testAWindowLessThanFiveMinutesAwayIsNotScheduled() {
        let plan = NotificationPolicy.plan(
            input(windows: [slot(start: date(13, 2))], now: date(12)))

        XCTAssertTrue(plan.isEmpty)
    }

    func testAWindowExactlyFiveMinutesAwayIsStillScheduled() throws {
        let plan = NotificationPolicy.plan(
            input(windows: [slot(start: date(13, 5))], now: date(12)))

        XCTAssertEqual(try XCTUnwrap(plan.first).fireDate, date(12, 5))
    }

    // MARK: - Night

    func testAFireTimeBeforeSevenIsSkipped() {
        // 07:30 window would ring at 06:30.
        let plan = NotificationPolicy.plan(
            input(windows: [slot(start: date(7, 30))], now: date(5)))

        XCTAssertTrue(plan.isEmpty, "« jamais la nuit » is literal")
    }

    func testSevenInTheMorningIsTheFirstAllowedMinute() {
        let plan = NotificationPolicy.plan(
            input(windows: [slot(start: date(8))], now: date(5)))

        XCTAssertEqual(plan.count, 1)
    }

    func testTheEveningBoundaryIsIncludedAndLaterIsNot() {
        let boundary = NotificationPolicy.plan(
            input(windows: [slot(start: date(23))], now: date(12)))
        let tooLate = NotificationPolicy.plan(
            input(windows: [slot(start: date(23, 30))], now: date(12)))

        XCTAssertEqual(boundary.count, 1, "22:00 is the last evening lead-in")
        XCTAssertTrue(tooLate.isEmpty, "22:30 is night")
    }

    // MARK: - Cap and ordering

    func testThePlanIsCappedAtEightSoonestFirst() {
        let windows = (9 ... 18).map { slot(start: date($0)) }
        let plan = NotificationPolicy.plan(input(windows: windows, now: date(7)))

        XCTAssertEqual(plan.count, 8)
        XCTAssertEqual(plan.first?.fireDate, date(8))
        XCTAssertEqual(plan.last?.fireDate, date(15))
    }

    func testThePlanIsSortedEvenWhenTheWindowsAreNot() {
        let windows = [slot(start: date(16)), slot(start: date(11)), slot(start: date(14))]
        let plan = NotificationPolicy.plan(input(windows: windows, now: date(8)))

        XCTAssertEqual(plan.map(\.fireDate), [date(10), date(13), date(15)])
    }

    func testADuplicatedWindowProducesOneRequest() {
        let window = slot(start: date(13))
        let plan = NotificationPolicy.plan(input(windows: [window, window], now: date(10)))

        XCTAssertEqual(plan.count, 1)
    }

    // MARK: - Identifiers

    func testTheIdentifierNamesTheSpotTheActivityAndTheWindowStart() throws {
        let start = date(13, 10)
        let plan = NotificationPolicy.plan(input(windows: [slot(start: start)], now: date(10)))

        let notification = try XCTUnwrap(plan.first)
        let epoch = Int(start.timeIntervalSince1970)
        XCTAssertEqual(notification.id, "estran.arcachon-eyrac.shoreFishing.window.\(epoch)")
        XCTAssertTrue(notification.id.hasPrefix("estran."))
    }

    func testTheSameWindowKeepsTheSameIdentifierAcrossReschedules() {
        let windows = [slot(start: date(13))]
        let first = NotificationPolicy.plan(input(windows: windows, now: date(10)))
        let second = NotificationPolicy.plan(input(windows: windows, now: date(10, 30)))

        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }

    // MARK: - Copy

    func testTheBodyNamesTheActivityTheSpotAndTheWindow() throws {
        let plan = NotificationPolicy.plan(input(
            windows: [slot(start: date(13, 10), duration: 2.5 * 60 * 60)],
            now: date(10)))

        let notification = try XCTUnwrap(plan.first)
        XCTAssertEqual(notification.title, "Estran")
        XCTAssertEqual(notification.body, "Pêche à pied à Arcachon-Eyrac : 13 h 10 à 15 h 40.")
    }

    func testNoBodyEverCarriesAVerdict() {
        for activity in Activity.allCases where activity != .swimming {
            let plan = NotificationPolicy.plan(input(
                windows: [slot(start: date(13), activity: activity)],
                now: date(10),
                activity: activity))

            XCTAssertEqual(plan.count, 1)
            for notification in plan {
                XCTAssertFalse(notification.body.contains("Oui"))
            }
        }
    }

    // MARK: - Exclusions

    func testSwimmingPlansNothingEvenWhenItsWindowsAreGood() {
        let windows = [slot(start: date(13), activity: .swimming)]
        let plan = NotificationPolicy.plan(input(
            windows: windows,
            now: date(10),
            activity: .swimming))

        XCTAssertTrue(plan.isEmpty, "swimming is a permanent risk, not an event")
    }

    func testWithoutTheOptInNothingIsPlanned() {
        let plan = NotificationPolicy.plan(input(
            windows: [slot(start: date(13))],
            now: date(10),
            alertsEnabled: false))

        XCTAssertTrue(plan.isEmpty)
    }

    // MARK: - Scheduler adapter

    private func snapshot(
        activity: Activity = .shoreFishing,
        isSampleData: Bool = false) -> WidgetSnapshot
    {
        WidgetSnapshot(
            updatedAt: date(10),
            spotID: "arcachon-eyrac",
            spotName: "Arcachon-Eyrac",
            activity: activity,
            isGo: true,
            isUnavailable: false,
            answer: "13 h 10 à 15 h 40",
            isSampleData: isSampleData)
    }

    func testTheSchedulerRequestsOneNotificationPerPlannedWindow() async {
        let center = RecordingNotificationCenter()
        let scheduler = LocalNotificationScheduler(center: center, alertsEnabled: { true })
        let windows = [slot(start: date(13)), slot(start: date(15))]

        await scheduler.reschedule(for: snapshot(), windows: windows, now: date(10))

        let added = await center.added
        let requests = await center.authorizationRequests
        XCTAssertEqual(added.count, 2)
        XCTAssertEqual(requests, 1, "the prompt is asked once, with something to schedule")
    }

    func testSampleDataNeverSchedulesAndNeverPrompts() async {
        let center = RecordingNotificationCenter()
        let scheduler = LocalNotificationScheduler(center: center, alertsEnabled: { true })

        await scheduler.reschedule(
            for: snapshot(isSampleData: true),
            windows: [slot(start: date(13))],
            now: date(10))

        let added = await center.added
        let requests = await center.authorizationRequests
        XCTAssertTrue(added.isEmpty, "demo data must never ring a real bell")
        XCTAssertEqual(requests, 0)
    }

    func testARescheduleRemovesOnlyItsOwnPendingRequests() async {
        let owned = "estran.arcachon-eyrac.shoreFishing.window.1"
        let foreign = "system.reminder"
        let center = RecordingNotificationCenter(pending: [owned, foreign])
        let scheduler = LocalNotificationScheduler(center: center, alertsEnabled: { false })

        await scheduler.reschedule(for: snapshot(), windows: [], now: date(10))

        let removed = await center.removed
        XCTAssertEqual(removed, [[owned]], "a future feature keeps its own requests")
    }
}

/// An in-memory notification centre: the adapter is tested without a device, an
/// authorisation prompt or a real pending list.
private actor RecordingNotificationCenter: NotificationCenterProtocol {
    private(set) var added: [PlannedNotification] = []
    private(set) var removed: [[String]] = []
    private(set) var authorizationRequests = 0

    private let pending: [String]
    private let grantsAuthorization: Bool

    init(pending: [String] = [], grantsAuthorization: Bool = true) {
        self.pending = pending
        self.grantsAuthorization = grantsAuthorization
    }

    func requestAuthorization() async throws -> Bool {
        authorizationRequests += 1
        return grantsAuthorization
    }

    func pendingIdentifiers() async -> [String] {
        pending
    }

    func add(_ notification: PlannedNotification) async throws {
        added.append(notification)
    }

    func removePending(identifiers: [String]) async {
        removed.append(identifiers)
    }
}
