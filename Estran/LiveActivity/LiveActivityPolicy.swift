import EstranCore
import Foundation

/// When the Live Activity exists, in one place, without a clock.
///
/// Every question takes `now` as an argument: a policy that reads
/// `Date()` internally cannot be tested on a running window, a window in six
/// hours or a window that ended twenty minutes ago. The controller owns the
/// calls; this type owns the rules.
enum LiveActivityPolicy {
    /// How far ahead a window is worth announcing. Two hours covers the walk to
    /// the beach without keeping a lock-screen card alive all afternoon.
    static let lookahead: TimeInterval = 2 * 60 * 60

    /// Grace period after a window ends. The last minutes are exactly when a
    /// fisherman is still packing up; the card disappears 15 min later, never
    /// while the window is open.
    static let endGrace: TimeInterval = 15 * 60

    /// `true` when a good window is running, or when the next one starts within
    /// the lookahead.
    static func shouldRun(now: Date, current: ActivitySlot?, upcoming: ActivitySlot?) -> Bool {
        // A window that contains `now` is running until its end, not until the
        // instant the slot was computed.
        if let current, current.window.end > now {
            return true
        }
        if let upcoming, upcoming.window.start.timeIntervalSince(now) <= lookahead {
            // A window that already ended is never run, even when a caller
            // passes it as "upcoming": a card for a closed window would lie.
            return upcoming.window.end > now
        }
        return false
    }

    /// `true` when nothing is running any more: no current window at all, or a
    /// window that ended more than the grace period ago.
    ///
    /// A running window always answers `false`, so a refresh while the user is
    /// still in the window can never dismiss the card under their eyes.
    static func shouldEnd(now: Date, current: ActivitySlot?) -> Bool {
        guard let current else {
            return true
        }
        return now.timeIntervalSince(current.window.end) > endGrace
    }

    /// The start of the next good window, for `ContentState.nextWindowStart`.
    ///
    /// `nil` when nothing is upcoming, when the window already began, or when
    /// the caller passed the running window twice: a window that contains `now`
    /// is the current one, never « le prochain ».
    static func nextWindowStart(now: Date, current: ActivitySlot?, upcoming: ActivitySlot?) -> Date? {
        guard let upcoming, upcoming.window.start > now else {
            return nil
        }
        if let current, current.window == upcoming.window {
            return nil
        }
        return upcoming.window.start
    }
}
