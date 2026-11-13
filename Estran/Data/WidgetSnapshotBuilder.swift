import EstranCore
import Foundation

/// Builds the widget snapshot from what the app just computed.
///
/// Formatting happens here, once: the widget extension receives French strings
/// and cannot drift from the app's wording (« — » for a missing measurement,
/// « estimée » for the lagoon sea, the windows as the app writes them).
enum WidgetSnapshotBuilder {
    /// Everything the snapshot needs, in one value so the builder keeps a
    /// readable parameter list.
    struct Input {
        let conditions: Conditions
        let overviews: [ActivityOverview]
        let activity: Activity
        /// `nil` only when `activity` is not offered at the spot: the snapshot
        /// then carries the not-offered sentence instead of a decision.
        let decision: GoDecision?
        let timeZone: TimeZone
        let isSampleData: Bool
    }

    static func make(_ input: Input) -> WidgetSnapshot {
        let conditions = input.conditions
        let activity = input.activity
        let timeZone = input.timeZone
        let isSampleData = input.isSampleData

        // The spot's offer is the single source of truth for the lines: an
        // activity the spot does not offer (surf at Eyrac) never appears, and
        // nothing renders a blank row in its place.
        let offeredOverviews = input.overviews.filter { conditions.spot.supports($0.activity) }

        let isNotOffered = !conditions.spot.supports(activity)
        let decision = input.decision

        let swimmingAdvisory: SwimmingAdvisory? = if activity == .swimming, let decision {
            SwimmingAdvisory(decision: decision, conditions: conditions)
        } else {
            nil
        }

        return WidgetSnapshot(
            updatedAt: conditions.at,
            spotID: conditions.spot.id,
            spotName: conditions.spot.name,
            activity: activity,
            isGo: activity == .swimming ? false : (!isNotOffered && (decision?.go ?? false)),
            isUnavailable: !isNotOffered && (decision?.isDataUnavailable ?? false),
            answer: isNotOffered
                ? ActivityOffer.notOfferedSentence(activity: activity, spot: conditions.spot)
                : answer(for: activity, decision: decision, overviews: offeredOverviews, timeZone: timeZone),
            swimmingAdvisory: swimmingAdvisory,
            lines: offeredOverviews.map { line(for: $0, region: conditions.spot.region, timeZone: timeZone) },
            metrics: metrics(for: conditions),
            isSampleData: isSampleData,
            isNotOffered: isNotOffered)
    }

    // MARK: - Answers

    private static func answer(
        for activity: Activity,
        decision: GoDecision?,
        overviews: [ActivityOverview],
        timeZone: TimeZone) -> String
    {
        guard let overview = overviews.first(where: { $0.activity == activity }) else {
            return decision?.reason ?? ""
        }
        return lineAnswer(overview, timeZone: timeZone)
    }

    private static func line(
        for overview: ActivityOverview,
        region: Region,
        timeZone: TimeZone) -> WidgetSnapshot.ActivityLine
    {
        if overview.activity == .swimming {
            let level = SwimmingRiskLevel(decision: overview.decision)
            return WidgetSnapshot.ActivityLine(
                activity: .swimming,
                isUnavailable: overview.isUnavailable,
                isGo: false,
                answer: level.label,
                warning: overview.isUnavailable ? nil : level.widgetWarning(for: region),
                swimmingLevel: level)
        }
        return WidgetSnapshot.ActivityLine(
            activity: overview.activity,
            isUnavailable: overview.isUnavailable,
            isGo: overview.decision.go,
            answer: lineAnswer(overview, timeZone: timeZone),
            warning: ActivityCaution.combined(overview.decision))
    }

    /// The same words the spot-detail rows use.
    private static func lineAnswer(
        _ overview: ActivityOverview,
        timeZone: TimeZone) -> String
    {
        if overview.isUnavailable {
            return "Données indisponibles"
        }
        if overview.decision.go {
            guard let window = overview.current?.window ?? overview.upcoming?.window else {
                return "Créneau à confirmer"
            }
            return FrenchFormat.range(window, in: timeZone, reference: overview.decision.computedAt)
        }
        return phrase(overview.decision.reason)
    }

    /// « Marge insuffisante. » → « Marge insuffisante ».
    private static func phrase(_ reason: String) -> String {
        var text = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasSuffix(".") {
            text.removeLast()
        }
        return text
    }

    // MARK: - Metrics

    static func metrics(for conditions: Conditions) -> [WidgetSnapshot.Metric] {
        let swell = conditions.swell
        return [
            WidgetSnapshot.Metric(
                id: "tide",
                symbol: FrenchFormat.tideSymbol(conditions.tide),
                value: conditions.tide.current.map { "\(FrenchFormat.height($0.height)) m" } ?? "—",
                caption: FrenchFormat.tideTrendShort(conditions.tide)),
            WidgetSnapshot.Metric(
                id: "wind",
                symbol: "wind",
                value: FrenchFormat.windSpeed(conditions.weather.wind),
                caption: "km/h \(FrenchFormat.windDirection(conditions.weather.wind))"),
            WidgetSnapshot.Metric(
                id: "swell",
                symbol: "water.waves",
                value: FrenchFormat.swellHeight(swell),
                caption: FrenchFormat.swellTileLabel(swell),
                // « période 11 s » wraps in a widget pill; the compact form is
                // the same measurement, one line (`W-PILL`).
                compactCaption: FrenchFormat.swellTileShortLabel(swell)),
            WidgetSnapshot.Metric(
                id: "weather",
                symbol: FrenchFormat.weatherSymbol(conditions.weather.condition),
                value: FrenchFormat.temperature(conditions.weather.temperature),
                caption: FrenchFormat.weatherLabel(conditions.weather.condition))
        ]
    }
}
