import ActivityKit
import EstranCore
import Foundation
import SwiftUI
import WidgetKit

/// The ActivityKit-facing bridge from a `GoActivityAttributes` context to what
/// the card draws. The layout, the verdict and the swimming signals live in
/// `LiveActivityCard.swift`, which is also compiled into the test target so the
/// card can be rendered and measured without an ActivityKit context.
extension ActivityViewContext where Attributes == GoActivityAttributes {
    /// Swimming when the state says so, when an advisory travels with it, or
    /// when the activity name is « Baignade ». Three independent signals, so a
    /// single stale flag cannot turn the card into a verdict.
    var isSwimmingActivity: Bool {
        LiveActivityCardState.isSwimming(
            activityName: state.activityName,
            isSwimming: state.isSwimming,
            advisory: state.swimmingAdvisory)
    }

    var swimmingAdvisoryOrUnknown: SwimmingAdvisory {
        state.swimmingAdvisory ?? SwimmingAdvisory(level: .unknown, region: .bassin)
    }

    var liveVerdict: LiveActivityVerdict {
        LiveActivityVerdict(
            isSwimming: isSwimmingActivity,
            isUnavailable: state.isUnavailable,
            isGo: state.isGo,
            level: swimmingAdvisoryOrUnknown.level)
    }

    /// The card shows times in the spot's zone, never the traveller's device
    /// zone: an Arcachon window is read in Arcachon time.
    var spotTimeZone: TimeZone {
        SpotCatalog.spot(id: attributes.spotID)?.timezone ?? .current
    }
}
