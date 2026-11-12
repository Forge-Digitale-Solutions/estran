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
        /// `true` when the data cannot answer: « Données indisponibles », never
        /// a `Non`. Defaulted so a state written by a previous build decodes.
        public var isUnavailable: Bool
        /// The caution the app's answer card shows for this verdict — night,
        /// light rain or the Bassin passes — verbatim, or `nil`. Copy only: it
        /// never becomes a verdict. Defaulted so a state written by a previous
        /// build decodes.
        public var caution: String?

        public init(
            isGo: Bool,
            activityName: String,
            nextWindowStart: Date?,
            updatedAt: Date,
            isSwimming: Bool = false,
            swimmingAdvisory: SwimmingAdvisory? = nil,
            isUnavailable: Bool = false,
            caution: String? = nil)
        {
            self.isGo = isGo
            self.activityName = activityName
            self.nextWindowStart = nextWindowStart
            self.updatedAt = updatedAt
            self.isSwimming = isSwimming
            self.swimmingAdvisory = swimmingAdvisory
            self.isUnavailable = isUnavailable
            self.caution = caution
        }

        /// Tolerates a state written before `isUnavailable` and `caution`
        /// existed: an absent flag is a readable verdict, an absent caution is
        /// no caution — never an unavailable card and never invented copy.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            isGo = try container.decode(Bool.self, forKey: .isGo)
            activityName = try container.decode(String.self, forKey: .activityName)
            nextWindowStart = try container.decodeIfPresent(
                Date.self, forKey: .nextWindowStart)
            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
            isSwimming = try container.decodeIfPresent(Bool.self, forKey: .isSwimming) ?? false
            swimmingAdvisory = try container.decodeIfPresent(
                SwimmingAdvisory.self, forKey: .swimmingAdvisory)
            isUnavailable = try container.decodeIfPresent(Bool.self, forKey: .isUnavailable) ?? false
            caution = try container.decodeIfPresent(String.self, forKey: .caution)
        }
    }

    public var spotID: String
    public var spotName: String

    public init(spotID: String, spotName: String) {
        self.spotID = spotID
        self.spotName = spotName
    }
}
