import Foundation

/// Everything the swimming card needs: the current level, the factual
/// conditions line and the non-current blockers in words.
///
/// The level speaks **only about currents**. Wind, swell, water temperature,
/// night and storm are shown as separate notes; they never raise the current
/// level, so « courants forts » keeps a single meaning (review v9, Z31).
public struct SwimmingAdvisory: Codable, Hashable, Sendable {
    public let level: SwimmingRiskLevel
    public let region: Region
    /// « Vent 38 km/h · houle 1,5 m · eau 17 °C », or `nil` when the data is
    /// not available at all.
    public let conditionsLine: String?
    /// Non-current blockers, e.g. `["vent fort", "houle trop forte"]`.
    public let notes: [String]

    public init(
        level: SwimmingRiskLevel,
        region: Region,
        conditionsLine: String? = nil,
        notes: [String] = [])
    {
        self.level = level
        self.region = region
        self.conditionsLine = conditionsLine
        self.notes = notes
    }

    /// Builds the advisory from a decision and the conditions it was computed
    /// from. The level comes from the current blockers; the notes from the
    /// other safety gates.
    public init(decision: GoDecision, conditions: Conditions) {
        self.init(
            level: SwimmingRiskLevel(decision: decision),
            region: conditions.spot.region,
            conditionsLine: Self.conditionsLine(for: conditions),
            notes: Self.notes(for: decision.blockers))
    }

    public var warning: String {
        level.warning(for: region)
    }

    /// One VoiceOver sentence in the visual order: warning first, then
    /// conditions, blockers and the secondary current level.
    public var accessibilitySentence: String {
        var parts = ["Baignade", warning]
        if let conditionsLine {
            parts.append(conditionsLine)
        }
        if !notes.isEmpty {
            parts.append(Self.sentenceCase(notes.joined(separator: ", ")))
        }
        parts.append(level.label)
        return parts.joined(separator: ". ")
    }

    /// « vent fort » → « Vent fort », so VoiceOver does not read
    /// « … eau 17 °C. vent fort. ».
    private static func sentenceCase(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// « Vent 38 km/h · houle 1,5 m · eau 17 °C ».
    public static func conditionsLine(for conditions: Conditions) -> String {
        var parts: [String] = []
        parts.append("Vent \(Int(conditions.weather.wind.speed.rounded())) km/h")
        parts.append("houle \(decimal(conditions.swell.waveHeight, digits: 1)) m")
        if let water = conditions.swell.seaSurfaceTemperature {
            parts.append("eau \(Int(water.rounded())) °C")
        } else {
            parts.append("eau indisponible")
        }
        return parts.joined(separator: " · ")
    }

    /// French words for the blockers that are **not** about currents.
    ///
    /// Blockers absent from the table are deliberately silent: currents are the
    /// level, and a data gap is either the unknown level or the « eau
    /// indisponible » conditions line.
    public static func notes(for blockers: [ActivityBlocker]) -> [String] {
        var seen = Set<String>()
        var notes: [String] = []
        for blocker in blockers {
            guard let note = notesByBlocker[blocker], seen.insert(note).inserted else {
                continue
            }
            notes.append(note)
        }
        return notes
    }

    private static let notesByBlocker: [ActivityBlocker: String] = [
        .storm: "orage",
        .wind: "vent fort",
        .swellTooLarge: "houle trop forte",
        .waveTooLarge: "houle trop forte",
        .waterTemperature: "eau froide",
        .temperature: "air froid",
        .night: "la nuit",
        .rain: "pluie",
        .fog: "brouillard",
        .waveTooSmall: "mer trop plate",
        .wavePeriod: "période de houle inadaptée",
        .swellDirection: "houle mal orientée",
        .onshoreWind: "vent onshore",
        .visibility: "visibilité insuffisante"
    ]

    private static func decimal(_ value: Double, digits: Int) -> String {
        String(format: "%.\(digits)f", value)
            .replacingOccurrences(of: ".", with: ",")
    }
}
