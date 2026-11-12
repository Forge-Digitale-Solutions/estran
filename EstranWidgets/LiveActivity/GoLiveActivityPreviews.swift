import ActivityKit
import EstranCore
import Foundation
import SwiftUI
import WidgetKit

#if DEBUG
    /// Xcode previews for the agreed Live Activity states, on all four surfaces
    /// (lock screen, expanded, compact, minimal): plain go, go with the night
    /// caution, go with the Bassin-passes caution, no go, swimming, unavailable.
    ///
    /// The swimming fixture is deliberately hostile: it carries `isGo: true`
    /// and a window, so the preview is also the visual proof that the view
    /// refuses « Oui » and the go green on its own (invariant 1).
    private enum LiveActivityPreview {
        static let attributes = GoActivityAttributes(
            spotID: SpotCatalog.pointeDeGrave.id,
            spotName: SpotCatalog.pointeDeGrave.name)

        static let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

        static let go = state(activity: .shoreFishing, isGo: true, nextWindow: 1500)

        /// The night caution on a `Oui` — the case the lock screen used to drop.
        static let goNight = state(
            activity: .shoreFishing,
            isGo: true,
            nextWindow: 1500,
            caution: ActivityCaution.nightFishing)

        /// The long Bassin-passes caution, the worst case for the ~160 pt card.
        static let goPasses = state(
            activity: .boating,
            isGo: true,
            nextWindow: 1500,
            caution: ActivityCaution.boatingPasses)

        static let noGo = state(activity: .surfing, isGo: false)

        static let unavailable = state(activity: .walking, isGo: false, isUnavailable: true)

        static let swimming = GoActivityAttributes.ContentState(
            isGo: true,
            activityName: EstranCore.Activity.swimming.displayName,
            nextWindowStart: now.addingTimeInterval(1500),
            updatedAt: now,
            isSwimming: true,
            swimmingAdvisory: SwimmingAdvisory(
                level: .strong,
                region: .medoc,
                conditionsLine: "Vent 38 km/h · houle 1,5 m · eau 17 °C",
                notes: ["vent fort", "houle trop forte"]))

        private static func state(
            activity: EstranCore.Activity,
            isGo: Bool,
            nextWindow: TimeInterval? = nil,
            isUnavailable: Bool = false,
            caution: String? = nil) -> GoActivityAttributes.ContentState
        {
            GoActivityAttributes.ContentState(
                isGo: isGo,
                activityName: activity.displayName,
                nextWindowStart: nextWindow.map(now.addingTimeInterval),
                updatedAt: now,
                isUnavailable: isUnavailable,
                caution: caution)
        }
    }

    #Preview("Écran verrouillé", as: .content, using: LiveActivityPreview.attributes) {
        GoLiveActivityWidget()
    } contentStates: {
        LiveActivityPreview.go
        LiveActivityPreview.goNight
        LiveActivityPreview.goPasses
        LiveActivityPreview.noGo
        LiveActivityPreview.swimming
        LiveActivityPreview.unavailable
    }

    #Preview(
        "Dynamic Island — expanded",
        as: .dynamicIsland(.expanded),
        using: LiveActivityPreview.attributes)
    {
        GoLiveActivityWidget()
    } contentStates: {
        LiveActivityPreview.go
        LiveActivityPreview.goNight
        LiveActivityPreview.goPasses
        LiveActivityPreview.noGo
        LiveActivityPreview.swimming
        LiveActivityPreview.unavailable
    }

    #Preview(
        "Dynamic Island — compact",
        as: .dynamicIsland(.compact),
        using: LiveActivityPreview.attributes)
    {
        GoLiveActivityWidget()
    } contentStates: {
        LiveActivityPreview.go
        LiveActivityPreview.goNight
        LiveActivityPreview.goPasses
        LiveActivityPreview.noGo
        LiveActivityPreview.swimming
        LiveActivityPreview.unavailable
    }

    #Preview(
        "Dynamic Island — minimal",
        as: .dynamicIsland(.minimal),
        using: LiveActivityPreview.attributes)
    {
        GoLiveActivityWidget()
    } contentStates: {
        LiveActivityPreview.go
        LiveActivityPreview.goNight
        LiveActivityPreview.goPasses
        LiveActivityPreview.noGo
        LiveActivityPreview.swimming
        LiveActivityPreview.unavailable
    }
#endif
