import EstranCore
import Foundation
import OSLog
import UserNotifications

/// The four calls the scheduler makes to the notification centre, in one small
/// protocol so the adapter is tested with a recorder instead of the real centre.
protocol NotificationCenterProtocol: Sendable {
    /// Asks the system for permission. The system only shows the prompt once;
    /// later calls return the stored answer without prompting.
    func requestAuthorization() async throws -> Bool
    /// The identifiers already pending, so the adapter can remove its own.
    func pendingIdentifiers() async -> [String]
    func add(_ notification: PlannedNotification) async throws
    func removePending(identifiers: [String]) async
}

/// The real centre: `UNUserNotificationCenter`, wrapped so nothing else in the
/// app imports `UserNotifications` for scheduling.
struct SystemNotificationCenter: NotificationCenterProtocol {
    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    func pendingIdentifiers() async -> [String] {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.map(\.identifier)
    }

    func add(_ notification: PlannedNotification) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default

        // Calendar components rather than a time interval: a request scheduled
        // across a relaunch or an app update still fires at the wall-clock time
        // the window starts, not at a drifting offset.
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: notification.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: notification.id,
            content: content,
            trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    func removePending(identifiers: [String]) async {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

/// Schedules « une heure avant » local notifications from the same snapshot the
/// widgets read.
///
/// The actor owns the system calls, not the rules: `NotificationPolicy` decides
/// which notifications exist, this adapter requests them, reschedules them and
/// cancels its own. Every system call is `do/catch`: a refused notification is
/// never an app failure, and nothing here can crash a refresh.
actor LocalNotificationScheduler {
    static let shared = LocalNotificationScheduler()

    /// The App Group key the opt-in toggle writes. The same literal lives in
    /// `AlertOptInToggle`; reading the shared defaults is what keeps the toggle
    /// and the scheduler on one preference.
    static let alertsEnabledKey = "alertsEnabled"

    private static let logger = Logger(
        subsystem: "com.forgedigitale.estran",
        category: "notifications")

    private let center: any NotificationCenterProtocol
    /// Read lazily on every reschedule so turning the toggle off cancels on the
    /// next refresh. Injectable for tests; the default reads the App Group.
    private let alertsEnabled: @Sendable () -> Bool
    /// The authorisation answer, asked at most once per process. A change made
    /// in Réglages afterwards is picked up on the next launch, as the Alertes
    /// screen already does.
    private var isAuthorized: Bool?

    init(
        center: any NotificationCenterProtocol = SystemNotificationCenter(),
        alertsEnabled: @escaping @Sendable () -> Bool = LocalNotificationScheduler.storedAlertsEnabled)
    {
        self.center = center
        self.alertsEnabled = alertsEnabled
    }

    /// The production preference: the App Group defaults, never a local copy.
    static func storedAlertsEnabled() -> Bool {
        UserDefaults(suiteName: EstranAppGroup.identifier)?.bool(forKey: alertsEnabledKey) ?? false
    }

    /// Aligns the pending notifications with the windows the app just computed.
    ///
    /// - Parameters:
    ///   - snapshot: the shared snapshot; its spot, activity and sample flag
    ///     decide whether a notification is legitimate.
    ///   - windows: the good windows for `snapshot.activity`, already filtered
    ///     by the engine.
    ///   - now: the clock, injected so the past-fire-time rule is testable.
    func reschedule(for snapshot: WidgetSnapshot, windows: [ActivitySlot], now: Date) async {
        // Cancellation comes first and is unconditional: a window that is no
        // longer good, a spot change or an opt-out must clear what we already
        // requested. Only identifiers carrying our prefix are touched, so the
        // system and a future feature keep theirs.
        await removeOwnPendingRequests()

        // Demo data is not a forecast: a ring on sample data would be a lie.
        guard !snapshot.isSampleData else { return }

        // No opt-in, no request: the toggle is the single permission.
        let enabled = alertsEnabled()
        guard enabled else { return }

        // Swimming is a permanent risk level, not an event. Its window is not
        // a moment to be reminded of, and no notification may invite a swim.
        guard snapshot.activity != .swimming else { return }

        let timeZone = SpotCatalog.spot(id: snapshot.spotID)?.timezone
            ?? SpotCatalog.defaultSpot.timezone
        let plan = NotificationPolicy.plan(NotificationPolicy.Input(
            windows: windows,
            spotID: snapshot.spotID,
            spotName: snapshot.spotName,
            activity: snapshot.activity,
            timeZone: timeZone,
            alertsEnabled: enabled,
            now: now))

        // Nothing to say: no prompt, no authorisation request.
        guard !plan.isEmpty else { return }

        if isAuthorized == nil {
            do {
                isAuthorized = try await center.requestAuthorization()
            } catch {
                Self.logger.error(
                    "notification authorization failed: \(error.localizedDescription)")
                isAuthorized = false
            }
        }
        guard isAuthorized == true else { return }

        for notification in plan {
            do {
                try await center.add(notification)
            } catch {
                // One failed request never blocks the others: the remaining
                // windows are still worth a notification.
                Self.logger.error(
                    "notification \(notification.id, privacy: .public) failed: \(error.localizedDescription)")
            }
        }
    }

    /// Removes the pending requests this feature owns, and only those.
    private func removeOwnPendingRequests() async {
        let owned = await center.pendingIdentifiers()
            .filter { $0.hasPrefix(NotificationPolicy.identifierPrefix) }
        guard !owned.isEmpty else { return }
        await center.removePending(identifiers: owned)
    }
}
