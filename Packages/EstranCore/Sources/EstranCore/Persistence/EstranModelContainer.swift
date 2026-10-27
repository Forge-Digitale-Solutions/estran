#if canImport(SwiftData)
    import Foundation
    import SwiftData

    /// Persistence layer kept separate from the domain models.
    ///
    /// Domain structs stay plain `Sendable` values so widgets and tests can use them
    /// without linking SwiftData. Only the app needs the container below.
    public enum EstranModelContainer {
        /// Builds the shared SwiftData container.
        ///
        /// - Parameter inMemory: Uses an in-memory store, which is what tests should use.
        public static func make(inMemory: Bool = false) throws -> ModelContainer {
            let schema = Schema([
                FavoriteSpot.self,
                CachedForecast.self,
                CachedTide.self,
                AppSettings.self
            ])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                groupContainer: inMemory ? .automatic : .identifier(EstranAppGroup.identifier))
            return try ModelContainer(for: schema, configurations: [configuration])
        }
    }

    @Model
    public final class FavoriteSpot {
        @Attribute(.unique) public var spotID: String
        public var activityRawValues: [String]
        public var alertsEnabled: Bool

        public init(spotID: String, activityRawValues: [String] = [], alertsEnabled: Bool = false) {
            self.spotID = spotID
            self.activityRawValues = activityRawValues
            self.alertsEnabled = alertsEnabled
        }
    }

    @Model
    public final class CachedForecast {
        @Attribute(.unique) public var cacheKey: String
        public var spotID: String
        public var fetchedAt: Date
        public var expiresAt: Date
        public var payload: Data

        public init(cacheKey: String, spotID: String, fetchedAt: Date, expiresAt: Date, payload: Data) {
            self.cacheKey = cacheKey
            self.spotID = spotID
            self.fetchedAt = fetchedAt
            self.expiresAt = expiresAt
            self.payload = payload
        }
    }

    @Model
    public final class CachedTide {
        @Attribute(.unique) public var cacheKey: String
        public var stationID: String
        public var day: Date
        public var payload: Data

        public init(cacheKey: String, stationID: String, day: Date, payload: Data) {
            self.cacheKey = cacheKey
            self.stationID = stationID
            self.day = day
            self.payload = payload
        }
    }

    @Model
    public final class AppSettings {
        @Attribute(.unique) public var id: String
        public var defaultSpotID: String?
        public var defaultActivityRawValue: String?
        public var notificationsEnabled: Bool

        public init(
            id: String = "default",
            defaultSpotID: String? = nil,
            defaultActivityRawValue: String? = nil,
            notificationsEnabled: Bool = false)
        {
            self.id = id
            self.defaultSpotID = defaultSpotID
            self.defaultActivityRawValue = defaultActivityRawValue
            self.notificationsEnabled = notificationsEnabled
        }
    }
#endif
