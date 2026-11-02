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

    static func range(_ interval: DateInterval, in timeZone: TimeZone) -> String {
        "\(time(interval.start, in: timeZone)) à \(time(interval.end, in: timeZone))"
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
        "\(height(swell.waveHeight)) m"
    }

    static func swellPeriod(_ swell: Swell) -> String {
        "\(Int(swell.period.rounded())) s"
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
        case .rain: "cloud.rain"
        case .showers: "cloud.drizzle"
        case .thunderstorm: "cloud.bolt"
        case .fog: "cloud.fog"
        case .snow: "cloud.snow"
        case .unknown: "cloud"
        }
    }

    // MARK: - Tide

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
}
