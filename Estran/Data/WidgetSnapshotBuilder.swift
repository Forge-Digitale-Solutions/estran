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
        let decision: GoDecision
        let timeZone: TimeZone
        let isSampleData: Bool
    }

    static func make(_ input: Input) -> WidgetSnapshot {
        let conditions = input.conditions
        let overviews = input.overviews
        let activity = input.activity
        let decision = input.decision
        let timeZone = input.timeZone
        let isSampleData = input.isSampleData

        return WidgetSnapshot(
            updatedAt: conditions.at,
            spotID: conditions.spot.id,
            spotName: conditions.spot.name,
            activity: activity,
            isGo: activity == .swimming ? false : decision.go,
            isUnavailable: decision.isDataUnavailable,
            answer: answer(for: activity, decision: decision, overviews: overviews, timeZone: timeZone),
            swimmingAdvisory: activity == .swimming
                ? SwimmingAdvisory(decision: decision, conditions: conditions)
                : nil,
            lines: overviews.map { line(for: $0, region: conditions.spot.region, timeZone: timeZone) },
            metrics: metrics(for: conditions),
            isSampleData: isSampleData)
    }

    // MARK: - Answers

    private static func answer(
        for activity: Activity,
        decision: GoDecision,
        overviews: [ActivityOverview],
        timeZone: TimeZone) -> String
    {
        guard let overview = overviews.first(where: { $0.activity == activity }) else {
            return decision.reason
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
            answer: lineAnswer(overview, timeZone: timeZone))
    }

    /// The same words the spot-detail rows use.
    private static func lineAnswer(_ overview: ActivityOverview, timeZone: TimeZone) -> String {
        if overview.isUnavailable {
            return "Données indisponibles"
        }
        if overview.decision.go {
            guard let window = overview.current?.window ?? overview.upcoming?.window else {
                return "Créneau à confirmer"
            }
            return FrenchFormat.range(window, in: timeZone)
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
        let swellCaption = swell.isEstimated
            ? "estimée · \(FrenchFormat.swellPeriod(swell))"
            : FrenchFormat.swellPeriod(swell)
        return [
            WidgetSnapshot.Metric(
                id: "tide",
                symbol: "water.waves",
                value: conditions.tide.current.map { "\(FrenchFormat.height($0.height)) m" } ?? "—",
                caption: FrenchFormat.tideTrendShort(conditions.tide)),
            WidgetSnapshot.Metric(
                id: "wind",
                symbol: "wind",
                value: FrenchFormat.windSpeed(conditions.weather.wind),
                caption: "km/h \(FrenchFormat.windDirection(conditions.weather.wind))"),
            WidgetSnapshot.Metric(
                id: "swell",
                symbol: "wave.3.right",
                value: FrenchFormat.swellHeight(swell),
                caption: swellCaption),
            WidgetSnapshot.Metric(
                id: "weather",
                symbol: FrenchFormat.weatherSymbol(conditions.weather.condition),
                value: FrenchFormat.temperature(conditions.weather.temperature),
                caption: FrenchFormat.weatherLabel(conditions.weather.condition))
        ]
    }
}
