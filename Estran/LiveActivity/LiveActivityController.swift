import ActivityKit
import EstranCore
import Foundation
import OSLog

/// The ActivityKit handle for Estran's Live Activity. `EstranCore` already has
/// an `Activity` enum (pêche à pied, surf, …); naming the handle keeps the two
/// apart at every call site.
private typealias LiveActivityHandle = ActivityKit.Activity<GoActivityAttributes>

/// Owns the app's Live Activity: start it before a good window, refresh it from
/// the same snapshot the widgets read, end it once the window is over.
///
/// The controller decides nothing on its own. `LiveActivityPolicy` answers
/// *when*, `WidgetSnapshot` provides *what*; the widget extension renders it and
/// never recomputes a verdict. The ActivityKit failure paths are logged and
/// swallowed: the app must never fail because a Live Activity could not start.
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    /// A state stays valid for 15 minutes. Past that the system marks it stale
    /// instead of letting the lock screen promise an old verdict.
    static let staleAfter: TimeInterval = 15 * 60

    private static let logger = Logger(
        subsystem: "com.forgedigitalesolutions.estran",
        category: "live-activity")

    /// The one ActivityKit operation in flight.
    ///
    /// Refreshes arrive from several paths (reload, activity change, spot
    /// change) and can overlap. Without a single slot, two of them could both
    /// read an empty `Activity.activities` list and each request a card.
    private var syncTask: Task<Void, Never>?

    private init() {}

    /// Aligns the Live Activity with the decision the app just computed.
    ///
    /// - Parameters:
    ///   - snapshot: the shared `WidgetSnapshot`, written by the app after each
    ///     refresh; the Live Activity and the widgets never diverge.
    ///   - current: the good window that contains now, if any.
    ///   - upcoming: the first good window that starts after now, if any.
    ///   - now: injected so the policy stays testable; the app passes the clock.
    func sync(
        snapshot: WidgetSnapshot,
        current: ActivitySlot?,
        upcoming: ActivitySlot?,
        now: Date = Date())
    {
        // No authorisation (user setting, unsupported device): no Live Activity
        // and no retry loop. A card the system refuses is not an app error.
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        let state = Self.contentState(
            snapshot: snapshot,
            current: current,
            upcoming: upcoming,
            now: now)

        if LiveActivityPolicy.shouldRun(now: now, current: current, upcoming: upcoming) {
            let attributes = GoActivityAttributes(
                spotID: snapshot.spotID,
                spotName: snapshot.spotName)
            enqueue { [weak self] in
                await self?.startOrUpdate(attributes: attributes, state: state, now: now)
            }
        } else if LiveActivityPolicy.shouldEnd(now: now, current: current) {
            // Never end a window that is still running: `shouldEnd` refuses it,
            // so a refresh inside the window only ever updates.
            enqueue { [weak self] in
                await self?.end(state: state)
            }
        }
    }

    /// Ends every card, without content, because the app has no data left to
    /// describe. Called when the store loses its conditions: a card that keeps
    /// describing a window the app can no longer compute would be a stale
    /// verdict on the lock screen.
    func endAll(reason: String) {
        Self.logger.info("Live Activity ended: \(reason, privacy: .public)")
        enqueue { [weak self] in
            await self?.endEverything()
        }
    }

    // MARK: - Serialisation

    /// Queues one operation behind the previous one, cancelling it first.
    ///
    /// The new task waits for the replaced one to leave, so only one task ever
    /// walks `Activity.activities` and requests a card. The operation captures
    /// `self` weakly: the stored task never keeps the controller alive.
    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = syncTask
        previous?.cancel()
        syncTask = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            await operation()
        }
    }

    // MARK: - State

    /// The state the Live Activity renders. Pure and internal, so the swimming
    /// rule is unit-tested without a device or an authorisation.
    ///
    /// **Swimming is a risk level, never a `Oui`** (`ARCHITECTURE_PLAN.md`
    /// §7.3): the flag is forced to `false` and the advisory travels with the
    /// state. An unavailable verdict is not a `Non` either: the flag is carried
    /// so every surface can say « Données indisponibles » instead.
    static func contentState(
        snapshot: WidgetSnapshot,
        current: ActivitySlot?,
        upcoming: ActivitySlot?,
        now: Date) -> GoActivityAttributes.ContentState
    {
        let isSwimming = snapshot.activity == .swimming
        // Swimming keeps its level and advisory: its unavailable inputs are
        // already visible there, and a second « Données indisponibles » line
        // would hide the risk level the user must read.
        let isUnavailable = !isSwimming && snapshot.isUnavailable
        return GoActivityAttributes.ContentState(
            isGo: !isSwimming && snapshot.isGo && !snapshot.isUnavailable,
            activityName: snapshot.activity.displayName,
            nextWindowStart: LiveActivityPolicy.nextWindowStart(
                now: now,
                current: current,
                upcoming: upcoming),
            updatedAt: now,
            isSwimming: isSwimming,
            swimmingAdvisory: isSwimming ? snapshot.swimmingAdvisory : nil,
            isUnavailable: isUnavailable,
            // The app's own composed caution (night, light rain, the Bassin
            // passes), read from the snapshot so no wording is duplicated here.
            // Swimming is nil by construction: its advisory carries the warning.
            caution: snapshot.caution)
    }

    // MARK: - ActivityKit

    private func startOrUpdate(
        attributes: GoActivityAttributes,
        state: GoActivityAttributes.ContentState,
        now: Date) async
    {
        let content = ActivityContent(
            state: state,
            staleDate: now.addingTimeInterval(Self.staleAfter))

        // The spot lives in the attributes, fixed when the card is requested: a
        // card from the previous spot cannot be renamed. It is ended first, or
        // the lock screen would name Pointe de Grave while the app says
        // Arcachon (no stale cross-spot state, M3 checklist). `.immediate`
        // here too: the old spot's card must not sit next to the new one.
        var kept: [LiveActivityHandle] = []
        for activity in LiveActivityHandle.activities {
            guard !Task.isCancelled else { return }
            if activity.attributes.spotID == attributes.spotID {
                kept.append(activity)
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        guard !Task.isCancelled else { return }

        guard kept.isEmpty else {
            for activity in kept {
                guard !Task.isCancelled else { return }
                await activity.update(content)
            }
            return
        }

        // Last check before the request: a replaced sync must never create the
        // second card the new one is about to look for.
        guard !Task.isCancelled else { return }

        do {
            _ = try LiveActivityHandle.request(
                attributes: attributes,
                content: content,
                pushType: nil)
        } catch {
            Self.logger.error("Live Activity start failed: \(error.localizedDescription)")
        }
    }

    /// Ends every card with the last state, immediately.
    ///
    /// `.immediate` is the only dismissal policy in this file. `.default`
    /// leaves an ended card on the lock screen for hours, which is exactly the
    /// stale « Oui » the window's end must not produce; a normal hand-off from
    /// one window to the next is an `update`, never an `end`, so no `.default`
    /// case is left.
    private func end(state: GoActivityAttributes.ContentState) async {
        let content = ActivityContent(state: state, staleDate: nil)
        for activity in LiveActivityHandle.activities {
            await activity.end(content, dismissalPolicy: .immediate)
        }
    }

    /// No data at all: no honest state to leave behind, so the card goes
    /// without content.
    private func endEverything() async {
        for activity in LiveActivityHandle.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
