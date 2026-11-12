import Foundation

/// French copy for an activity a spot does **not offer**.
///
/// This is not a verdict and not a missing value: surf is simply not possible
/// at the Eyrac jetty inside the Bassin, and every surface (app, widget, Siri)
/// says so in the same words instead of turning it into a `Non` or a
/// « Données indisponibles » (owner decision 2026-11-12).
public enum ActivityOffer {
    /// « Pas de surf à Arcachon-Eyrac » — the not-offered headline.
    public static func notOfferedTitle(activity: Activity, spot: Spot) -> String {
        switch activity {
        case .surfing:
            "Pas de surf à \(spot.name)"
        case .shoreFishing, .boating, .walking, .swimming:
            "\(activity.displayName) n'est pas proposé à \(spot.name)"
        }
    }

    /// The factual pointer to where the activity does happen, or `nil` when no
    /// pointer is needed.
    public static func notOfferedDetail(activity: Activity) -> String? {
        switch activity {
        case .surfing:
            // Surf happens on the ocean side, never inside the Bassin.
            "Le surf, c'est côté océan : Cap Ferret ou la Salie."
        case .shoreFishing, .boating, .walking, .swimming:
            nil
        }
    }

    /// One sentence for Siri and the snapshot answer: title, then the detail.
    public static func notOfferedSentence(activity: Activity, spot: Spot) -> String {
        let title = notOfferedTitle(activity: activity, spot: spot)
        guard let detail = notOfferedDetail(activity: activity) else {
            return title + "."
        }
        return "\(title). \(detail)"
    }
}

/// Permanent, factual cautions shown next to a verdict. They are copy only:
/// they never enter the decision engine, so they can never change a verdict.
public enum ActivityCaution {
    /// The Bassin's passes are dangerous regardless of the wind or the sea the
    /// rules read: open-ocean swell and shifting sandbanks.
    public static let boatingPasses =
        "Les passes du Bassin restent dangereuses : houle de l'océan et bancs qui bougent."

    /// Light-rain reminder for the two rain-gated activities that tolerate a
    /// drizzle (owner decision 2026-11-12).
    public static let rainJacket = "Prévois une veste : petite pluie possible."

    /// Night is not forbidden for pêche à pied: the caution replaces a `Non`
    /// (owner decision 2026-11-12).
    public static let nightFishing =
        "De nuit : lampe frontale, et surveille la marée qui remonte."

    /// Boating at night is a legal activity with its own lights.
    public static let nightBoating = "De nuit : feux de navigation obligatoires."

    /// The caution for `activity` at `spot`, or `nil` when none applies.
    public static func caution(activity: Activity, spot: Spot) -> String? {
        if activity == .boating, spot.region == .bassin {
            return boatingPasses
        }
        return nil
    }

    /// The light-rain caution for `activity`, or `nil` when the weather is not
    /// a light rain or the activity is not rain-gated (fishing and walking).
    public static func rainCaution(activity: Activity, weather: WeatherNow) -> String? {
        guard activity == .shoreFishing || activity == .walking,
              RuleSignals.isLightRain(weather)
        else {
            return nil
        }
        return rainJacket
    }

    /// The night caution for `activity`, or `nil` when it is not night or the
    /// activity is not one of the two night-tolerant ones.
    ///
    /// Night never blocks pêche à pied or boating (owner decision 2026-11-12):
    /// it lowers the score a little and adds a caution. Balade, surf and
    /// baignade are untouched — swimming keeps its own `.night` blocker.
    public static func nightCaution(
        activity: Activity,
        at date: Date,
        coordinate: Coordinate,
        uncertainty: TimeInterval = 0) -> String?
    {
        guard activity == .shoreFishing || activity == .boating,
              SolarDaylight.isNight(
                  at: date,
                  coordinate: coordinate,
                  uncertainty: uncertainty)
        else {
            return nil
        }
        return activity == .shoreFishing ? nightFishing : nightBoating
    }

    /// The conditional cautions of a decision: night first, then the light-rain
    /// reminder, kept as short sentences. `nil` when neither applies.
    public static func conditionalCaution(
        activity: Activity,
        conditions: Conditions) -> String?
    {
        joined([
            nightCaution(
                activity: activity,
                at: conditions.at,
                coordinate: conditions.spot.coordinate,
                uncertainty: conditions.spot.uncertainty.timeInterval),
            rainCaution(activity: activity, weather: conditions.weather)
        ])
    }

    /// Every caution a decision's surfaces show, in reading order: the
    /// conditional part (night, then rain) followed by the permanent spot
    /// caution (the Bassin passes). `nil` when none applies.
    public static func combined(_ decision: GoDecision) -> String? {
        joined([
            decision.caution,
            caution(activity: decision.activity, spot: decision.spot)
        ])
    }

    /// Joins the non-nil parts with a single space; `nil` when all are absent.
    private static func joined(_ parts: [String?]) -> String? {
        let text = parts.compactMap(\.self).joined(separator: " ")
        return text.isEmpty ? nil : text
    }
}
