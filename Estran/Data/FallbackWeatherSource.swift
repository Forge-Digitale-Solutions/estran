import EstranCore
import Foundation
import OSLog

/// WeatherKit first, Open-Meteo when WeatherKit cannot answer.
///
/// **Why a fallback.** WeatherKit needs the App ID capability and a signed
/// build (`BUILD.md` §2). Without that capability — or when a quota or network
/// failure hits — the primary throws `.weatherUnavailable`. The product must
/// still answer, and a keyless Open-Meteo forecast is the same kind of data
/// from the same class of source, so the app does not depend on a portal
/// setting to work.
///
/// **Not a silent substitution.** The fallback is logged, and neither source
/// ever returns a neutral value: when both fail, the provider throws and the UI
/// says « Données indisponibles ». The branch that answered is also recorded
/// (`WeatherAttributionStore`), because each provider has its own attribution
/// duty: the Apple Weather mark for WeatherKit, CC BY 4.0 for Open-Meteo.
struct FallbackWeatherSource: WeatherSource {
    private static let logger = Logger(subsystem: "com.forgedigitalesolutions.estran", category: "weather")

    private let primary: any WeatherSource
    private let fallback: any WeatherSource

    init(
        primary: any WeatherSource = WeatherKitService(),
        fallback: any WeatherSource = OpenMeteoWeatherService())
    {
        self.primary = primary
        self.fallback = fallback
    }

    func weather(for spot: Spot, at date: Date) async throws -> WeatherNow {
        do {
            let value = try await primary.weather(for: spot, at: date)
            await Self.record(primary.kind, for: spot)
            return value
        } catch {
            Self.logger.notice(
                "WeatherKit unavailable, using Open-Meteo: \(String(describing: error), privacy: .public)")
            let value = try await fallback.weather(for: spot, at: date)
            await Self.record(fallback.kind, for: spot)
            return value
        }
    }

    func forecast(for spot: Spot, from date: Date, hours: Int) async throws -> [WeatherNow] {
        do {
            return try await primary.forecast(for: spot, from: date, hours: hours)
        } catch {
            Self.logger.notice(
                "WeatherKit forecast unavailable, using Open-Meteo: \(String(describing: error), privacy: .public)")
            return try await fallback.forecast(for: spot, from: date, hours: hours)
        }
    }

    /// Records the source of the **current** conditions only.
    ///
    /// The forecast is a separate call and could in theory take the other
    /// branch; the cards the user reads (« Météo 22° », « vent 14 km/h ») are
    /// the current sample, so that is the value the credit must describe.
    private static func record(_ kind: WeatherSourceKind?, for spot: Spot) async {
        await WeatherAttributionStore.shared.record(kind, forSpotID: spot.id)
    }
}
