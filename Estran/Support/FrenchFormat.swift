import EstranCore
import Foundation

/// French formatting for every user-facing value.
///
/// The app is French-only: it uses a comma decimal separator, a 24-hour clock
/// written « 14 h 12 », and French compass points (O for Ouest, not W). Values
/// are formatted here so Home, the map and the widgets cannot disagree.
enum FrenchFormat {
    // MARK: - Time

    static func time(_ date: Date, in timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return "\(hour) h \(String(format: "%02d", minute))"
    }

    /// « 15 h 30 à 17 h 30 » today, « demain 8 h 30 à 10 h 30 » later, or
    /// « ce soir 19 h 21 → demain 17 h 21 » across local midnight.
    ///
    /// The day is named whenever the window does not start and end on the same
    /// local day as today, so a range that crosses midnight can never read as a
    /// same-day window.
    static func range(
        _ interval: DateInterval,
        in timeZone: TimeZone,
        reference: Date) -> String
    {
        let start = interval.start
        let end = interval.end
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        if calendar.isDate(start, inSameDayAs: end) {
            if calendar.isDate(start, inSameDayAs: reference) {
                return "\(time(start, in: timeZone)) à \(time(end, in: timeZone))"
            }
            return "\(dayPrefix(start, in: timeZone, reference: reference)) "
                + "\(time(start, in: timeZone)) à \(time(end, in: timeZone))"
        }

        let startPrefix = calendar.isDate(start, inSameDayAs: reference)
            ? (isEvening(start, in: timeZone) ? "ce soir" : "aujourd'hui")
            : dayPrefix(start, in: timeZone, reference: reference)
        let endPrefix = dayPrefix(end, in: timeZone, reference: reference)
        return "\(startPrefix) \(time(start, in: timeZone)) → "
            + "\(endPrefix) \(time(end, in: timeZone))"
    }

    /// « demain », « après-demain », or « aujourd'hui ». A window lives inside a
    /// 48 h horizon, so anything further is unreachable and falls back to the
    /// weekday name.
    private static func dayPrefix(_ date: Date, in timeZone: TimeZone, reference: Date) -> String {
        if let relative = relativeDay(date, in: timeZone, reference: reference) {
            return relative
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        if calendar.isDate(date, inSameDayAs: reference) {
            return "aujourd'hui"
        }
        return weekdayOnly(date, in: timeZone)
    }

    /// Whether the local hour is 17 h or later, when « ce soir » reads better
    /// than « aujourd'hui ».
    private static func isEvening(_ date: Date, in timeZone: TimeZone) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return (calendar.component(.hour, from: date)) >= 17
    }

    /// The weekday alone, for a window past « après-demain » (unreachable in a
    /// 48 h horizon, but kept so the formatter never prints an empty day).
    private static func weekdayOnly(_ date: Date, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    /// « lundi 26 oct. » in the spot's time zone, for the spot detail subtitle.
    static func weekdayDate(_ date: Date, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEEE d MMM"
        return formatter.string(from: date)
    }

    /// « Bassin d'Arcachon » or « Médoc », the area name of a spot.
    ///
    /// The catalog's tide-station names are internal codes (`PORT-BLOC`,
    /// `ARCACHON_EYRAC`); they are never shown to a user.
    static func regionName(_ region: Region) -> String {
        switch region {
        case .bassin: "Bassin d'Arcachon"
        case .medoc: "Médoc"
        }
    }

    /// « demain », « après-demain », or `nil` for today and further out.
    static func relativeDay(
        _ date: Date,
        in timeZone: TimeZone,
        reference: Date) -> String?
    {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let from = calendar.startOfDay(for: reference)
        let to = calendar.startOfDay(for: date)
        guard let days = calendar.dateComponents([.day], from: from, to: to).day else {
            return nil
        }
        switch days {
        case 1: return "demain"
        case 2: return "après-demain"
        default: return nil
        }
    }

    // MARK: - Measures

    static func height(_ meters: Double) -> String {
        decimal(meters, fractionDigits: 1)
    }

    static func decimal(_ value: Double, fractionDigits: Int) -> String {
        String(format: "%.\(fractionDigits)f", value)
            .replacingOccurrences(of: ".", with: ",")
    }

    static func wind(_ wind: Wind) -> String {
        "\(Int(wind.speed.rounded())) km/h"
    }

    /// Speed alone, for the four-up tile row where the unit rides on the
    /// caption line (« 9 » / « km/h NO ») as in `DESIGN_REFERENCE.md` §3.1.
    static func windSpeed(_ wind: Wind) -> String {
        "\(Int(wind.speed.rounded()))"
    }

    static func windDirection(_ wind: Wind) -> String {
        cardinal(wind.directionDegrees)
    }

    static func cardinal(_ degrees: Double) -> String {
        let sectors = ["N", "NE", "E", "SE", "S", "SO", "O", "NO"]
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        let index = Int((normalized + 22.5) / 45) % sectors.count
        return sectors[index]
    }

    static func temperature(_ celsius: Double) -> String {
        "\(Int(celsius.rounded()))°"
    }

    /// « 24 février 2026 » from a dataset `yyyy-MM-dd` value.
    ///
    /// The dataset date is the source's last update, not a hand-written string:
    /// it must move with the data (early M3 review, point 9).
    static func longDate(fromISO value: String) -> String? {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: value) else { return nil }

        let display = DateFormatter()
        display.locale = Locale(identifier: "fr_FR")
        display.timeZone = TimeZone(identifier: "UTC")
        display.dateStyle = .long
        return display.string(from: date)
    }

    static func swellHeight(_ swell: Swell) -> String {
        let prefix = swell.isEstimated ? "≈ " : ""
        return "\(prefix)\(height(swell.waveHeight)) m"
    }

    static func swellPeriod(_ swell: Swell) -> String {
        "\(Int(swell.period.rounded())) s"
    }

    /// Short caption for the swell tile: the period, or « estimée » when the
    /// sea is a local wind-sea estimate and the period is itself an estimate,
    /// not an observation. Keeps the tile the same visual weight as the others.
    static func swellTileLabel(_ swell: Swell) -> String {
        swell.isEstimated ? "estimée" : swellPeriod(swell)
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded())) %"
    }

    // MARK: - Weather

    static func weatherLabel(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear: "ensoleillé"
        case .partlyCloudy: "éclaircies"
        case .cloudy: "nuageux"
        case .drizzle: "bruine"
        case .rain: "pluie"
        case .showers: "averses"
        case .thunderstorm: "orage"
        case .fog: "brouillard"
        case .snow: "neige"
        case .unknown: "indisponible"
        }
    }

    static func weatherSymbol(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear: "sun.max"
        case .partlyCloudy: "cloud.sun"
        case .cloudy: "cloud"
        case .drizzle: "cloud.drizzle"
        case .rain: "cloud.rain"
        case .showers: "cloud.heavyrain"
        case .thunderstorm: "cloud.bolt"
        case .fog: "cloud.fog"
        case .snow: "cloud.snow"
        case .unknown: "cloud"
        }
    }

    // MARK: - Tide

    /// SF Symbol for the tide tile, chosen from the trend: a wave with an
    /// up/down arrow when rising/falling, plain waves when the trend is unknown.
    static func tideSymbol(_ state: TideState) -> String {
        switch state.isRising {
        case .some(true): "water.waves.and.arrow.trianglehead.up"
        case .some(false): "water.waves.and.arrow.trianglehead.down"
        case .none: "water.waves"
        }
    }

    static func tideTrend(_ state: TideState) -> String {
        switch state.isRising {
        case .some(true): "montante"
        case .some(false): "descendante"
        case .none: "indisponible"
        }
    }

    /// One short word for the tile caption: « descendante » hyphenates in an
    /// 80 pt tile at the default size, and a hyphenated tide is worse than a
    /// shorter word. The spoken label keeps `tideTrend`.
    static func tideTrendShort(_ state: TideState) -> String {
        switch state.isRising {
        case .some(true): "hausse"
        case .some(false): "baisse"
        case .none: "—"
        }
    }

    static func tideEventKind(_ kind: TideEvent.Kind) -> String {
        switch kind {
        case .high: "Marée haute"
        case .low: "Marée basse"
        }
    }

    // MARK: - Empty window

    /// The short French reason for a windowless 48 h horizon, from its dominant
    /// blocker, or `nil` when there is nothing precise to say (keep the generic
    /// sentence then).
    static func emptyWindowReason(_ blocker: ActivityBlocker?) -> String? {
        guard let blocker else { return nil }
        switch blocker {
        case .night:
            return "Pas de créneau de jour d'ici 48 h : les marées basses tombent la nuit."
        case .dataUnavailable, .currentDataUnavailable:
            // These are handled by the « Créneaux indisponibles » state, never by
            // the no-window sentence.
            return nil
        default:
            return "Pas de créneau d'ici 48 h : \(firstLowercased(blocker.shortLabel))."
        }
    }

    /// « Coefficient trop faible » → « coefficient trop faible ».
    private static func firstLowercased(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).lowercased() + String(text.dropFirst())
    }
}
