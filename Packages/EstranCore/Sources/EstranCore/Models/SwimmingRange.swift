import Foundation

/// Per-spot thresholds for the swimming current level, calibrated on the
/// **local predicted tidal range**, not on the national coefficient.
///
/// The current in the passes follows the local range. `lowBelow` and `strongAt`
/// delimit a grey band of ±0.30 m around `T`, the range reached on the same
/// number of days as the national coefficient reaches 100 at Brest. No `low`
/// level is possible inside the band: a range we cannot classify is never
/// presented as « courants faibles ».
public struct SwimmingRange: Codable, Hashable, Sendable {
    /// At or above this range the level is at least `moderate`.
    public let lowBelow: Double
    /// At or above this range, with the phase inside 0.4...0.6, the level is
    /// `strong`.
    public let strongAt: Double

    public init(lowBelow: Double, strongAt: Double) {
        self.lowBelow = lowBelow
        self.strongAt = strongAt
    }

    /// A usable band: positive lower bound, strictly below the strong threshold.
    public var isValid: Bool {
        lowBelow > 0 && lowBelow < strongAt
    }
}
