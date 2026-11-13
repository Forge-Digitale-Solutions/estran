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

    /// A walk after dark needs a light, nothing more (owner decision
    /// 2026-11-13, same treatment as pêche à pied and bateau).
    public static let nightWalking = "De nuit : lampe frontale."

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

    /// The night caution for `activity` at the decision instant, or `nil` when
    /// it is daylight or the activity is not one of the three night-tolerant
    /// ones.
    ///
    /// Night never blocks pêche à pied, boating or balade (owner decisions
    /// 2026-11-12 and 2026-11-13): it lowers the score a little and adds a
    /// caution. Surf and baignade are untouched — swimming keeps its own
    /// `.night` blocker.
    ///
    /// The **plain instant** is read, never the tide's uncertainty envelope
    /// (`W-NIGHTFIX`): `u_t` is the uncertainty of the tide prediction, not of
    /// the clock, and the sun's position at a given instant is certain. Using
    /// the envelope put « De nuit » in broad daylight at 09:08 after an 08:20
    /// sunrise.
    public static func nightCaution(
        activity: Activity,
        at date: Date,
        coordinate: Coordinate) -> String?
    {
        guard toleratesNight(activity),
              SolarDaylight.isNight(at: date, coordinate: coordinate)
        else {
            return nil
        }
        return nightCautionText(activity: activity)
    }

    /// The night caution for a good **window**, or `nil` when the whole window
    /// is in daylight.
    ///
    /// A caution attached to a window describes that window: a run from 16:00
    /// to 19:00 in November ends after sunset and carries it, even if the app
    /// is opened at noon.
    public static func nightCaution(
        activity: Activity,
        window: DateInterval,
        coordinate: Coordinate) -> String?
    {
        guard toleratesNight(activity),
              SolarDaylight.isNight(in: window, coordinate: coordinate)
        else {
            return nil
        }
        return nightCautionText(activity: activity)
    }

    /// Activities that stay open after dark: pêche à pied, bateau and balade.
    private static func toleratesNight(_ activity: Activity) -> Bool {
        activity == .shoreFishing || activity == .boating || activity == .walking
    }

    /// The one-string copy of the night caution for an activity that tolerates
    /// the dark.
    private static func nightCautionText(activity: Activity) -> String {
        switch activity {
        case .shoreFishing: nightFishing
        case .walking: nightWalking
        case .boating: nightBoating
        // Unreachable: `toleratesNight` admits only the three cases above. Surf
        // and baignade never get here, so they borrow the neutral boating copy
        // rather than invent a night rule they do not have.
        case .surfing, .swimming: nightBoating
        }
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
                coordinate: conditions.spot.coordinate),
            rainCaution(activity: activity, weather: conditions.weather)
        ])
    }

    /// The cautions of a **good window**: night when any part of the window is
    /// dark, the light-rain reminder for the sample at the window's start, then
    /// the permanent spot caution (the Bassin passes).
    ///
    /// `nil` when there is no window: a card that says « Pas de créneau » has
    /// nothing to qualify, and must never repeat the current instant's caution
    /// under it (`W-NIGHTFIX`).
    public static func windowCaution(
        activity: Activity,
        window: DateInterval?,
        spot: Spot,
        weather: WeatherNow? = nil) -> String?
    {
        guard let window else { return nil }
        return joined([
            nightCaution(
                activity: activity,
                window: window,
                coordinate: spot.coordinate),
            weather.flatMap { rainCaution(activity: activity, weather: $0) },
            caution(activity: activity, spot: spot)
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
