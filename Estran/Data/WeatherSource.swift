import EstranCore
import Foundation

/// Air weather source: current conditions and an hourly series.
///
/// The production implementation wraps Apple WeatherKit (`WeatherKitService`);
/// the demo provider keeps its synthetic weather inside `#if DEBUG`. Both feed
/// the same `Conditions` shape, so the UI cannot tell them apart.
///
/// A source **never** substitutes a neutral value: if the data is missing, it
/// throws and the provider reports « Données indisponibles » (`AGENTS.md`
/// invariant 3 and 4).
protocol WeatherSource: Sendable {
    /// Which external provider this source is, for the on-screen attribution.
    /// `nil` for a fixture that no party needs credited; the production
    /// adapters both name themselves.
    var kind: WeatherSourceKind? { get }

    func weather(for spot: Spot, at date: Date) async throws -> WeatherNow

    /// `hours` hourly values starting at `date`, in order.
    func forecast(for spot: Spot, from date: Date, hours: Int) async throws -> [WeatherNow]
}

extension WeatherSource {
    var kind: WeatherSourceKind? {
        nil
    }
}
