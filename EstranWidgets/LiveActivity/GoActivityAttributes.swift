import ActivityKit
import EstranCore
import Foundation

/// Attributes shared by the app and the widget extension for Live Activities.
public struct GoActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var isGo: Bool
        public var activityName: String
        public var nextWindowStart: Date?
        public var updatedAt: Date
        /// Swimming is a risk level, never a Oui/Non (product decision, v8).
        public var isSwimming: Bool
        /// Level, conditions line, non-current blockers and warning (Z31).
        public var swimmingAdvisory: SwimmingAdvisory?

        public init(
            isGo: Bool,
            activityName: String,
            nextWindowStart: Date?,
            updatedAt: Date,
            isSwimming: Bool = false,
            swimmingAdvisory: SwimmingAdvisory? = nil)
        {
            self.isGo = isGo
            self.activityName = activityName
            self.nextWindowStart = nextWindowStart
            self.updatedAt = updatedAt
            self.isSwimming = isSwimming
            self.swimmingAdvisory = swimmingAdvisory
        }
    }

    public var spotID: String
    public var spotName: String

    public init(spotID: String, spotName: String) {
        self.spotID = spotID
        self.spotName = spotName
    }
}
