import Foundation

/// What the widgets and the Live Activity read: a small, already-formatted
/// snapshot written by the app after each refresh.
///
/// **Why a snapshot and not the domain objects.** The widget extension has no
/// store, no engine and no network: it must render in milliseconds from what the
/// app already computed. Strings are formatted in French by the app, so the
/// widget cannot invent its own wording or its own numbers.
///
/// **Never a fabricated value.** A missing measurement is an em dash in the app
/// and stays an em dash here; `lines` only ever contains answers the engine
/// produced.
public struct WidgetSnapshot: Codable, Hashable, Sendable {
    /// One activity answer, for the multi-activity widget (frame 04).
    public struct ActivityLine: Codable, Hashable, Sendable, Identifiable {
        public let activity: Activity
        /// `true` when the activity cannot be answered for lack of data.
        public let isUnavailable: Bool
        /// `Oui` / `Non`; ignored for swimming, which shows `answer` instead.
        public let isGo: Bool
        /// The visible answer: a window range, a reason, or a swimming level.
        public let answer: String
        /// A caution shown beside the answer: swimming's year-round baïnes
        /// warning, the Bassin boating caution about the passes, or the
        /// conditional night/light-rain reminder. Never a verdict.
        public let warning: String?
        /// Swimming only: the level, so the widget colours it like the app.
        public let swimmingLevel: SwimmingRiskLevel?

        public var id: String {
            activity.rawValue
        }

        public init(
            activity: Activity,
            isUnavailable: Bool,
            isGo: Bool,
            answer: String,
            warning: String? = nil,
            swimmingLevel: SwimmingRiskLevel? = nil)
        {
            self.activity = activity
            self.isUnavailable = isUnavailable
            self.isGo = isGo
            self.answer = answer
            self.warning = warning
            self.swimmingLevel = swimmingLevel
        }
    }

    /// One conditions tile (« Marée », « Vent », « Houle », « Météo »).
    public struct Metric: Codable, Hashable, Sendable, Identifiable {
        public let id: String
        public let symbol: String
        public let value: String
        public let caption: String

        public init(id: String, symbol: String, value: String, caption: String) {
            self.id = id
            self.symbol = symbol
            self.value = value
            self.caption = caption
        }

        /// The tile's name, so « 0,5 m / 6 s » is not left to be guessed.
        ///
        /// Derived from the identifier rather than stored: the snapshot written
        /// by a previous build must keep decoding, and a missing name is better
        /// than a schema the widget cannot read. An unknown identifier gets an
        /// empty name, and the views draw no empty caption for it.
        public var title: String {
            switch id {
            case "tide": "Marée"
            case "wind": "Vent"
            case "swell": "Houle"
            case "weather": "Météo"
            default: ""
            }
        }
    }

    public let updatedAt: Date
    public let spotID: String
    public let spotName: String
    /// The activity selected in the app, for the small widget.
    public let activity: Activity
    /// `Oui` / `Non` for the selected activity; always `false` for swimming.
    public let isGo: Bool
    public let isUnavailable: Bool
    /// Window range or reason, already in French.
    public let answer: String
    /// Swimming advisory for the small widget and the Live Activity.
    public let swimmingAdvisory: SwimmingAdvisory?
    public let lines: [ActivityLine]
    public let metrics: [Metric]
    /// `true` when the app ran on the DEBUG demo provider.
    public let isSampleData: Bool
    /// `true` when the selected activity is not offered at the spot (surf inside
    /// the Bassin). A distinct, visible state: never a `Non`, never missing data.
    public let isNotOffered: Bool

    public init(
        updatedAt: Date,
        spotID: String,
        spotName: String,
        activity: Activity,
        isGo: Bool,
        isUnavailable: Bool,
        answer: String,
        swimmingAdvisory: SwimmingAdvisory? = nil,
        lines: [ActivityLine] = [],
        metrics: [Metric] = [],
        isSampleData: Bool = false,
        isNotOffered: Bool = false)
    {
        self.updatedAt = updatedAt
        self.spotID = spotID
        self.spotName = spotName
        self.activity = activity
        self.isGo = isGo
        self.isUnavailable = isUnavailable
        self.answer = answer
        self.swimmingAdvisory = swimmingAdvisory
        self.lines = lines
        self.metrics = metrics
        self.isSampleData = isSampleData
        self.isNotOffered = isNotOffered
    }

    /// Tolerates a snapshot written before `isNotOffered` (and before the
    /// multi-activity `lines`/`metrics`) existed: an absent flag decodes as
    /// `false` and an absent list as empty, never as a fabricated state.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        spotID = try container.decode(String.self, forKey: .spotID)
        spotName = try container.decode(String.self, forKey: .spotName)
        activity = try container.decode(Activity.self, forKey: .activity)
        isGo = try container.decode(Bool.self, forKey: .isGo)
        isUnavailable = try container.decode(Bool.self, forKey: .isUnavailable)
        answer = try container.decode(String.self, forKey: .answer)
        swimmingAdvisory = try container.decodeIfPresent(SwimmingAdvisory.self, forKey: .swimmingAdvisory)
        lines = try container.decodeIfPresent([ActivityLine].self, forKey: .lines) ?? []
        metrics = try container.decodeIfPresent([Metric].self, forKey: .metrics) ?? []
        isSampleData = try container.decodeIfPresent(Bool.self, forKey: .isSampleData) ?? false
        isNotOffered = try container.decodeIfPresent(Bool.self, forKey: .isNotOffered) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case updatedAt
        case spotID
        case spotName
        case activity
        case isGo
        case isUnavailable
        case answer
        case swimmingAdvisory
        case lines
        case metrics
        case isSampleData
        case isNotOffered
    }

    /// How long a snapshot stays usable. Past this the widget says it is waiting
    /// for fresh data instead of showing a stale sea.
    public static let staleAfter: TimeInterval = 2 * 60 * 60

    public var isStale: Bool {
        Date().timeIntervalSince(updatedAt) > Self.staleAfter
    }

    /// The selected activity's caution, taken from its own line: the composed
    /// night/light-rain reminder plus the permanent spot caution (the Bassin
    /// passes), exactly as the app's answer card shows it. `nil` for swimming
    /// (its advisory already carries the baïnes warning), when the activity has
    /// no line, or when that line has no caution — never invented copy.
    public var caution: String? {
        guard activity != .swimming,
              let warning = lines.first(where: { $0.activity == activity })?.warning
        else {
            return nil
        }
        let text = warning.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    // MARK: - App Group storage

    public static let fileName = "widget-snapshot.json"

    /// The shared container, or `nil` outside an entitled context (unit tests,
    /// Linux CI).
    public static func containerURL(
        fileManager: FileManager = .default) -> URL?
    {
        #if canImport(Darwin)
            // App Group containers are an Apple-platform API: on Linux the core
            // package must still build, and a `nil` container is exactly what the
            // caller expects when the group is not provisioned.
            return fileManager
                .containerURL(forSecurityApplicationGroupIdentifier: EstranAppGroup.identifier)?
                .appendingPathComponent("Widget", isDirectory: true)
        #else
            _ = fileManager
            return nil
        #endif
    }

    public func save(in containerURL: URL? = WidgetSnapshot.containerURL()) throws {
        guard let containerURL else {
            throw WidgetSnapshotError.containerUnavailable
        }
        try FileManager.default.createDirectory(
            at: containerURL,
            withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        // Seconds since 1970: an exact round-trip. ISO-8601 would drop the
        // sub-second part and the widget would see a different instant.
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(self)
        try data.write(
            to: containerURL.appendingPathComponent(Self.fileName),
            options: .atomic)
    }

    public static func load(
        from containerURL: URL? = WidgetSnapshot.containerURL()) -> WidgetSnapshot?
    {
        guard let url = containerURL?.appendingPathComponent(fileName),
              let data = try? Data(contentsOf: url)
        else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    // MARK: - Per-spot collection

    /// The file that holds one snapshot per spot, keyed by spot identifier.
    public static let collectionFileName = "widget-snapshots.json"

    /// Writes one snapshot per spot. The app refreshes both spots so a widget
    /// configured to either one has data without the app being open on it.
    public static func saveCollection(
        _ snapshots: [WidgetSnapshot],
        in containerURL: URL? = WidgetSnapshot.containerURL()) throws
    {
        guard let containerURL else {
            throw WidgetSnapshotError.containerUnavailable
        }
        try FileManager.default.createDirectory(
            at: containerURL,
            withIntermediateDirectories: true)
        let bySpot = Dictionary(
            snapshots.map { ($0.spotID, $0) },
            uniquingKeysWith: { _, newest in newest })
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(bySpot)
        try data.write(
            to: containerURL.appendingPathComponent(collectionFileName),
            options: .atomic)
    }

    public static func loadCollection(
        from containerURL: URL? = WidgetSnapshot.containerURL()) -> [String: WidgetSnapshot]?
    {
        guard let url = containerURL?.appendingPathComponent(collectionFileName),
              let data = try? Data(contentsOf: url)
        else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode([String: WidgetSnapshot].self, from: data)
    }

    /// The snapshot for `spotID`, from the per-spot collection when present.
    ///
    /// Backward compatibility: an older app wrote a single `widget-snapshot.json`
    /// for the selected spot only. That file is still honoured, but only for its
    /// own spot — it is never treated as a value for the other spot.
    public static func load(
        forSpotID spotID: String,
        from containerURL: URL? = WidgetSnapshot.containerURL()) -> WidgetSnapshot?
    {
        if let collection = loadCollection(from: containerURL) {
            return collection[spotID]
        }
        guard let single = load(from: containerURL), single.spotID == spotID else {
            return nil
        }
        return single
    }
}

public enum WidgetSnapshotError: Error, Equatable {
    case containerUnavailable
}
