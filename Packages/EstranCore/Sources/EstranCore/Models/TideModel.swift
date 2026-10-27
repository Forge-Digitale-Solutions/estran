import Foundation

/// Embedded tide dataset, decoded from `tide-model-<year>.<revision>.json`.
///
/// The model is our own harmonic fit of REFMAR observations (Licence Ouverte
/// 2.0). It is never official and never fetched at runtime. The loader is the
/// only path from the generated JSON to `TidalStation`/`TideEngine`, so the
/// contract can be tested without manual patching.
public struct TideModel: Codable, Hashable, Sendable {
    /// Accuracy block of a station entry (review Z21/Z25).
    ///
    /// Only the fields the contract needs are decoded; the extrema and forward
    /// test stay in the JSON as information. `maxUnderPredictionMeters` and
    /// `minOverPredictionMeters` are **required when the block is present**:
    /// the loader must not accept a dataset that only publishes the ambiguous
    /// two-sided maximum.
    public struct Accuracy: Codable, Hashable, Sendable {
        public let samples: Int
        public let rmseMeters: Double?
        public let biasMeters: Double?
        public let p95HeightErrorMeters: Double?
        public let maxUnderPredictionMeters: Double?
        public let minOverPredictionMeters: Double?
        public let maxAbsoluteErrorMeters: Double?

        public init(
            samples: Int,
            rmseMeters: Double? = nil,
            biasMeters: Double? = nil,
            p95HeightErrorMeters: Double? = nil,
            maxUnderPredictionMeters: Double? = nil,
            minOverPredictionMeters: Double? = nil,
            maxAbsoluteErrorMeters: Double? = nil)
        {
            self.samples = samples
            self.rmseMeters = rmseMeters
            self.biasMeters = biasMeters
            self.p95HeightErrorMeters = p95HeightErrorMeters
            self.maxUnderPredictionMeters = maxUnderPredictionMeters
            self.minOverPredictionMeters = minOverPredictionMeters
            self.maxAbsoluteErrorMeters = maxAbsoluteErrorMeters
        }
    }

    /// One station entry in the dataset.
    public struct Station: Codable, Hashable, Sendable {
        public let id: String
        public let name: String
        public let role: String?
        public let coordinate: Coordinate
        public let timezoneIdentifier: String
        public let meanSeaLevel: Double
        public let meanSpringRange: Double
        public let constituents: [HarmonicConstituent]
        public let validUntil: Date?
        public let nodalCorrections: Bool
        public let attribution: String
        public let accuracy: Accuracy?

        public init(
            id: String,
            name: String,
            role: String? = nil,
            coordinate: Coordinate,
            timezoneIdentifier: String,
            meanSeaLevel: Double,
            meanSpringRange: Double,
            constituents: [HarmonicConstituent],
            validUntil: Date?,
            nodalCorrections: Bool,
            attribution: String,
            accuracy: Accuracy? = nil)
        {
            self.id = id
            self.name = name
            self.role = role
            self.coordinate = coordinate
            self.timezoneIdentifier = timezoneIdentifier
            self.meanSeaLevel = meanSeaLevel
            self.meanSpringRange = meanSpringRange
            self.constituents = constituents
            self.validUntil = validUntil
            self.nodalCorrections = nodalCorrections
            self.attribution = attribution
            self.accuracy = accuracy
        }

        /// Domain station built from the dataset entry.
        public var tidalStation: TidalStation {
            TidalStation(
                id: id,
                name: name,
                coordinate: coordinate,
                timezoneIdentifier: timezoneIdentifier,
                meanSeaLevel: meanSeaLevel,
                meanSpringRange: meanSpringRange,
                constituents: constituents,
                attribution: attribution,
                validUntil: validUntil,
                nodalCorrections: nodalCorrections)
        }
    }

    /// Local lag/amplitude correction applied to a spot's tide.
    ///
    /// `lagMinutes: 0, amplitudeFactor: 1` is only an identity **when**
    /// `correctionStatus == .calibrated`. With `.none` it means no correction
    /// is known and the uncertainty envelope carries the risk.
    public struct Correction: Codable, Hashable, Sendable {
        public let lagMinutes: Double
        public let amplitudeFactor: Double

        public init(lagMinutes: Double, amplitudeFactor: Double) {
            self.lagMinutes = lagMinutes
            self.amplitudeFactor = amplitudeFactor
        }

        public static let none = Correction(lagMinutes: 0, amplitudeFactor: 1)
    }

    /// One spot entry in the dataset.
    public struct SpotEntry: Codable, Hashable, Sendable {
        public let id: String
        public let stationId: String
        public let correction: Correction
        public let correctionStatus: CorrectionStatus
        public let validation: SpotValidation
        public let uncertainty: TideUncertainty
        /// Per-spot swimming thresholds from the local predicted range.
        public let swimmingRange: SwimmingRange?

        public init(
            id: String,
            stationId: String,
            correction: Correction = .none,
            correctionStatus: CorrectionStatus,
            validation: SpotValidation,
            uncertainty: TideUncertainty,
            swimmingRange: SwimmingRange? = nil)
        {
            self.id = id
            self.stationId = stationId
            self.correction = correction
            self.correctionStatus = correctionStatus
            self.validation = validation
            self.uncertainty = uncertainty
            self.swimmingRange = swimmingRange
        }
    }

    /// National coefficient block (review Z23).
    ///
    /// `validated == false` means the reference model is fitted but has not been
    /// checked against a published Annuaire sample. `SwimmingRule` requires the
    /// flag on `TideState`, so fixing the computation cannot enable baignade.
    public struct Coefficient: Codable, Hashable, Sendable {
        /// Reference station identifier (`3`, Brest), when included in the run.
        public let stationId: String?
        /// Conventional divisor: `C = range / divisor × 100`.
        public let divisor: Double
        public let validated: Bool
        public let validation: String?
        public let gateMarginPoints: Int?
        public let nodalDrift: String?

        public init(
            stationId: String?,
            divisor: Double,
            validated: Bool,
            validation: String? = nil,
            gateMarginPoints: Int? = nil,
            nodalDrift: String? = nil)
        {
            self.stationId = stationId
            self.divisor = divisor
            self.validated = validated
            self.validation = validation
            self.gateMarginPoints = gateMarginPoints
            self.nodalDrift = nodalDrift
        }
    }

    public let schemaVersion: Int
    public let source: String
    public let license: String
    public let retrievedAt: Date
    public let official: Bool
    public let sourceLastUpdate: String?
    public let coefficient: Coefficient?
    public let stations: [Station]
    public let spots: [SpotEntry]

    public init(
        schemaVersion: Int,
        source: String,
        license: String,
        retrievedAt: Date,
        official: Bool,
        sourceLastUpdate: String? = nil,
        coefficient: Coefficient? = nil,
        stations: [Station],
        spots: [SpotEntry])
    {
        self.schemaVersion = schemaVersion
        self.source = source
        self.license = license
        self.retrievedAt = retrievedAt
        self.official = official
        self.sourceLastUpdate = sourceLastUpdate
        self.coefficient = coefficient
        self.stations = stations
        self.spots = spots
    }

    /// Domain stations, in dataset order.
    public var tidalStations: [TidalStation] {
        stations.map(\.tidalStation)
    }

    /// Contract checks that must hold before the dataset can be loaded.
    ///
    /// **v1 scope (D3 = Option A):** the shipped catalog contains only the
    /// gauged spots. The loader therefore rejects an estimated spot, a
    /// calibrated/estimated correction, and an inactive envelope: under Option A
    /// the envelope *is* the safety argument, so a silent `0 / 0` would disable
    /// the fail-closed gate without anything noticing.
    public var validationError: TideError? {
        guard !official else {
            return .invalidStation("dataset must not claim official status")
        }
        guard !stations.isEmpty else {
            return .invalidStation("dataset has no stations")
        }
        guard stations.allSatisfy({ $0.validUntil != nil }) else {
            return .invalidStation("every station must declare validUntil")
        }
        for station in stations {
            if let accuracy = station.accuracy {
                guard accuracy.maxUnderPredictionMeters != nil else {
                    return .invalidStation(
                        "station \(station.id) accuracy must publish maxUnderPredictionMeters")
                }
                guard accuracy.minOverPredictionMeters != nil else {
                    return .invalidStation(
                        "station \(station.id) accuracy must publish minOverPredictionMeters")
                }
            }
        }
        if let coefficient {
            guard coefficient.divisor > 0 else {
                return .invalidStation("coefficient divisor must be positive")
            }
            guard abs(coefficient.divisor - HarmonicPredictor.nationalCoefficientDivisor) < 0.0001
            else {
                return .invalidStation(
                    "coefficient divisor \(coefficient.divisor) does not match the engine's "
                        + "\(HarmonicPredictor.nationalCoefficientDivisor)")
            }
            if let stationId = coefficient.stationId {
                guard let station = stations.first(where: { $0.id == stationId }) else {
                    return .invalidStation(
                        "coefficient references unknown station \(stationId)")
                }
                guard station.role == "coefficientReference" else {
                    return .invalidStation(
                        "coefficient station \(stationId) must declare the coefficientReference role")
                }
            } else if coefficient.validated {
                return .invalidStation(
                    "a validated coefficient requires a reference station")
            }
        }
        let stationIDs = Set(stations.map(\.id))
        for spot in spots {
            guard stationIDs.contains(spot.stationId) else {
                return .invalidStation("spot \(spot.id) references unknown station \(spot.stationId)")
            }
            guard spot.validation == .gauged else {
                return .invalidStation("spot \(spot.id) is not gauged; the v1 catalog ships gauged spots only")
            }
            guard spot.correctionStatus == .none else {
                return .invalidStation("spot \(spot.id) declares a correction; v1 gauged spots carry none")
            }
            guard spot.uncertainty.isActive else {
                return .invalidStation("spot \(spot.id) has an inactive uncertainty envelope")
            }
            if let swimmingRange = spot.swimmingRange, !swimmingRange.isValid {
                return .invalidStation(
                    "spot \(spot.id) has an invalid swimming range "
                        + "(\(swimmingRange.lowBelow)..\(swimmingRange.strongAt))")
            }
        }
        return nil
    }

    /// Builds the engine from the dataset, enforcing the contract first.
    public func engine() throws -> TideEngine {
        if let error = validationError {
            throw error
        }
        return try TideEngine(
            stations: tidalStations,
            coefficientStationID: coefficient?.stationId,
            coefficientValidated: coefficient?.validated ?? false)
    }

    /// Decodes a dataset from JSON, using ISO-8601 dates.
    public static func load(from data: Data) throws -> TideModel {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TideModel.self, from: data)
    }
}

/// The tide dataset embedded in the `EstranCore` resource bundle.
///
/// This is the only production path from the generated JSON to the engine. The
/// app, the widgets and the intents all read the same embedded model; nothing
/// is fetched at runtime.
public enum ShippedTideModel {
    /// Base name of the shipped dataset, without the `.json` extension.
    public static let resourceName = "tide-model-2026.1"

    /// Raised when the embedded dataset is missing from the resource bundle.
    public struct MissingResource: Error, CustomStringConvertible {
        public let name: String
        public var description: String {
            "missing embedded tide dataset \(name).json"
        }
    }

    /// Raw JSON of the embedded dataset.
    public static func data() throws -> Data {
        guard let url = Bundle.module.url(
            forResource: resourceName, withExtension: "json")
        else {
            throw MissingResource(name: resourceName)
        }
        return try Data(contentsOf: url)
    }

    /// Decodes and returns the embedded dataset. Callers should check
    /// `validationError` (or use `engine()`, which enforces it).
    public static func load() throws -> TideModel {
        try TideModel.load(from: data())
    }
}
