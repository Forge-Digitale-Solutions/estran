import EstranCore
import Foundation

/// One local notification the scheduler should request: what it says, when it
/// fires, and the identifier that lets a reschedule replace it.
///
/// Deliberately free of `UserNotifications`: the rules are tested on values, and
/// the adapter owns every call to the system.
struct PlannedNotification: Equatable, Sendable {
    let id: String
    let fireDate: Date
    let title: String
    let body: String
}

/// The rules that turn good windows into « une heure avant » notifications.
///
/// Pure: no clock, no storage, no system call. The scheduler passes the windows
/// the engine just computed, the spot's time zone and the user's preference;
/// this type decides which notifications are worth a pending request. Keeping
/// the rules here means the night exclusion and the lead time are testable
/// without a device, an authorisation or a notification centre.
enum NotificationPolicy {
    /// Everything the plan needs, in one value so the parameter list stays
    /// readable and the call sites cannot swap two strings.
    struct Input: Sendable {
        /// The good windows for `activity`, as the decision engine returned them.
        let windows: [ActivitySlot]
        /// Stable spot identifier, used in the notification identifier.
        let spotID: String
        /// Display name, used in the sentence.
        let spotName: String
        let activity: Activity
        /// The spot's time zone: the 07:00–22:00 rule is a local wall clock.
        let timeZone: TimeZone
        /// The user's opt-in, read from the App Group by the scheduler.
        let alertsEnabled: Bool
        /// The reference instant; the app passes the clock, tests pass a fixture.
        let now: Date
    }

    /// The notification title. One word: the user already knows which app rang.
    static let title = "Estran"

    /// One hour before the window starts, as the toggle promises.
    static let leadTime: TimeInterval = 60 * 60

    /// A notification that fires within five minutes is noise: the user is
    /// already getting ready or already left. Past fire times are dropped for
    /// the same reason.
    static let minimumLead: TimeInterval = 5 * 60

    /// At most eight pending requests. A long weekend of windows must not fill
    /// the user's notification centre.
    static let maximumCount = 8

    /// Local 07:00, the first minute a notification may fire.
    static let dayStartMinute = 7 * 60
    /// Local 22:00, the last minute a notification may fire.
    static let dayEndMinute = 22 * 60

    /// Prefix every identifier this feature owns; the scheduler removes only
    /// the requests that carry it.
    static let identifierPrefix = "estran."

    /// The notifications to schedule, soonest first.
    static func plan(_ input: Input) -> [PlannedNotification] {
        // No opt-in, nothing rings.
        guard input.alertsEnabled else { return [] }
        // Swimming is a permanent risk level, never an event: a reminder would
        // turn « baignade » into an invitation, which no surface may do.
        guard input.activity != .swimming else { return [] }

        var planned: [PlannedNotification] = []
        var seen = Set<String>()

        // Soonest window first, so the cap below drops the furthest ones.
        for slot in input.windows.sorted(by: { $0.window.start < $1.window.start }) {
            let fireDate = slot.window.start.addingTimeInterval(-leadTime)

            // A notification that arrives after the moment is noise.
            guard fireDate.timeIntervalSince(input.now) >= minimumLead else { continue }

            // « Jamais la nuit » is literal. A fire time outside 07:00–22:00
            // local (bounds inclusive) is dropped, so a 07:30 window never rings
            // at 06:30. The 22:00 bound keeps the last evening lead-in; later
            // than that the user is asleep or the window is not actionable.
            guard isDaytime(fireDate, in: input.timeZone) else { continue }

            let id = identifier(
                spotID: input.spotID,
                activity: input.activity,
                windowStart: slot.window.start)
            // Two windows cannot share an identifier, but two entries can (a
            // duplicated slot): one request per window, never a stack.
            guard seen.insert(id).inserted else { continue }

            planned.append(PlannedNotification(
                id: id,
                fireDate: fireDate,
                title: title,
                body: body(
                    activity: input.activity,
                    spotName: input.spotName,
                    window: slot.window,
                    timeZone: input.timeZone,
                    reference: input.now)))
        }

        return Array(planned.prefix(maximumCount))
    }

    /// « estran.<spotID>.<activity>.window.<startEpochSeconds> ».
    ///
    /// The window start, not the fire date: the identifier describes the event,
    /// so a reschedule of the same window replaces the pending request instead
    /// of stacking a second one.
    static func identifier(spotID: String, activity: Activity, windowStart: Date) -> String {
        let start = Int(windowStart.timeIntervalSince1970)
        return "\(identifierPrefix)\(spotID).\(activity.rawValue).window.\(start)"
    }

    /// « Pêche à pied à Arcachon-Eyrac : 13 h 10 à 15 h 40. »
    ///
    /// The body names the activity, the spot and the window, and never carries
    /// a verdict: a notification is a reminder of a time, not a `Oui`, so the
    /// swimming rule can never be broken by a sentence written here.
    static func body(
        activity: Activity,
        spotName: String,
        window: DateInterval,
        timeZone: TimeZone,
        reference: Date) -> String
    {
        let range = FrenchFormat.range(window, in: timeZone, reference: reference)
        return "\(activity.displayName) à \(spotName) : \(range)."
    }

    /// `true` when the fire time falls between 07:00 and 22:00 local, bounds
    /// inclusive.
    static func isDaytime(_ date: Date, in timeZone: TimeZone) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minuteOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return minuteOfDay >= dayStartMinute && minuteOfDay <= dayEndMinute
    }
}
