import EstranCore
import Foundation

/// Production conditions provider.
///
/// The tide comes from the embedded REFMAR-derived model and is available
/// today. The weather and swell sources land in **M2** (WeatherKit / Open-Meteo
/// Marine). Until they exist, this provider **refuses** instead of inventing
/// values: a fabricated favourable verdict is the one failure the product
/// cannot afford (`worksplit.md` M2).
struct LiveConditionsProvider: ConditionsProviding {
    let isSampleData = false

    private let tideEngine: TideEngine?

    init() {
        tideEngine = try? ShippedTideModel.load().engine()
    }

    func conditions(for _: Spot, at _: Date) async throws -> Conditions {
        guard tideEngine != nil else {
            throw ConditionsProviderError.tideUnavailable
        }
        // M2 owns the weather pipeline. No fallback values, no neutral defaults.
        throw ConditionsProviderError.weatherUnavailable
    }

    func forecast(for _: Spot, from _: Date, hours _: Int) async throws -> [Conditions] {
        throw ConditionsProviderError.weatherUnavailable
    }
}
