import Foundation

/// Geographic region covered by the initial spot catalog.
public enum Region: String, Codable, CaseIterable, Hashable, Sendable {
    case bassin
    case medoc
}

public struct Coordinate: Codable, Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct TideStationRef: Codable, Hashable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// How a spot's tide verdict is validated.
public enum SpotValidation: String, Codable, CaseIterable, Hashable, Sendable {
    /// The spot is close enough to a REFMAR gauge for a gauged verdict.
    case gauged
    /// The spot uses a gauge plus an open-coast correction; not validated.
    case estimatedOpenCoast
    /// The spot uses a gauge plus a lagoon correction; not validated.
    case estimatedLagoon
}

/// Whether a spot's lag/amplitude correction is calibrated.
///
/// `none` is **not** an identity claim: it means no local correction is known.
/// The uncertainty envelope carries the missing correction.
public enum CorrectionStatus: String, Codable, CaseIterable, Hashable, Sendable {
    /// No local correction exists. The model is used unshifted, with the
    /// uncertainty envelope accounting for the unknown lag and amplitude.
    case none
    /// A correction was derived and validated against independent observations.
    case calibrated
    /// A correction is proposed from a model or regional interpolation but has
    /// not been validated at the spot.
    case estimated
}

/// Bound-based uncertainty envelope used by the fail-closed safety gate.
///
/// Both values are **bounds**, not percentiles: a slot is `Oui` only when the
/// whole interval `[t − timeMinutes, t + timeMinutes]` and the whole height
/// range `[h − heightMeters, h + heightMeters]` are unblocked.
public struct TideUncertainty: Codable, Hashable, Sendable {
    /// Time bound in minutes, applied on both sides of the decision instant.
    public let timeMinutes: Double
    /// Height bound in meters, applied downwards for water-level gates.
    public let heightMeters: Double

    public init(timeMinutes: Double, heightMeters: Double) {
        self.timeMinutes = timeMinutes
        self.heightMeters = heightMeters
    }

    /// No envelope: used by synthetic fixtures and by exact-data callers.
    public static let none = TideUncertainty(timeMinutes: 0, heightMeters: 0)

    /// `true` when at least one bound is positive.
    public var isActive: Bool {
        timeMinutes > 0 || heightMeters > 0
    }

    /// The time bound in seconds.
    public var timeInterval: TimeInterval {
        timeMinutes * 60
    }
}

public struct Spot: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let region: Region
    public let coordinate: Coordinate
    public let tideStation: TideStationRef
    public let supportedActivities: Set<Activity>
    public let timezone: TimeZone
    /// Direction the shore faces, in degrees, used to tell offshore from onshore
    /// wind. `nil` when the orientation is not confirmed yet.
    public let coastOrientationDegrees: Double?
    /// Minimum water height in meters required by boats at this spot.
    /// `nil` applies the rule's conservative default (0.5 m); it is not neutral.
    public let minimumWaterHeight: Double?
    /// How the spot's tide verdict is validated.
    public let validation: SpotValidation
    /// Whether the local lag/amplitude correction is calibrated.
    public let correctionStatus: CorrectionStatus
    /// Bound-based envelope used by the fail-closed safety gate.
    public let uncertainty: TideUncertainty
    /// Per-spot swimming thresholds, calibrated on the local predicted range.
    /// `nil` means the swimming level cannot be estimated.
    public let swimmingRange: SwimmingRange?

    public init(
        id: String,
        name: String,
        region: Region,
        coordinate: Coordinate,
        tideStation: TideStationRef,
        supportedActivities: Set<Activity>,
        timezone: TimeZone,
        coastOrientationDegrees: Double? = nil,
        minimumWaterHeight: Double? = nil,
        validation: SpotValidation = .estimatedOpenCoast,
        correctionStatus: CorrectionStatus = .none,
        uncertainty: TideUncertainty = .none,
        swimmingRange: SwimmingRange? = nil)
    {
        self.id = id
        self.name = name
        self.region = region
        self.coordinate = coordinate
        self.tideStation = tideStation
        self.supportedActivities = supportedActivities
        self.timezone = timezone
        self.coastOrientationDegrees = coastOrientationDegrees
        self.minimumWaterHeight = minimumWaterHeight
        self.validation = validation
        self.correctionStatus = correctionStatus
        self.uncertainty = uncertainty
        self.swimmingRange = swimmingRange
    }

    /// Copy of the spot with the given envelope.
    public func withUncertainty(_ uncertainty: TideUncertainty) -> Spot {
        Spot(
            id: id,
            name: name,
            region: region,
            coordinate: coordinate,
            tideStation: tideStation,
            supportedActivities: supportedActivities,
            timezone: timezone,
            coastOrientationDegrees: coastOrientationDegrees,
            minimumWaterHeight: minimumWaterHeight,
            validation: validation,
            correctionStatus: correctionStatus,
            uncertainty: uncertainty,
            swimmingRange: swimmingRange)
    }

    /// User-facing model label.
    ///
    /// It never claims a live local measurement or SHOM officiality. Gauged
    /// spots name the reference station; estimated spots say « estimation ».
    public var modelLabel: String {
        switch validation {
        case .gauged:
            "modèle local — station \(tideStation.id)"
        case .estimatedOpenCoast, .estimatedLagoon:
            "estimation — modèle local"
        }
    }

    /// `true` when the spot offers `activity`.
    ///
    /// Arcachon-Eyrac does not offer surf: the jetty is inside the Bassin and
    /// nobody surfs there (`ARCHITECTURE_PLAN.md`, owner decision 2026-11-12).
    /// A not-offered activity is a distinct state, never a `Non` and never
    /// missing data.
    public func supports(_ activity: Activity) -> Bool {
        supportedActivities.contains(activity)
    }

    /// The activities offered at this spot, in `Activity.allCases` order.
    public var offeredActivities: [Activity] {
        Activity.allCases.filter { supportedActivities.contains($0) }
    }
}
