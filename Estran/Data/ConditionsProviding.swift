import EstranCore
import Foundation

/// Everything the UI needs to build a `Conditions` value.
///
/// The app never talks to a weather or tide API directly: it asks a provider.
/// The **same protocol** serves the real source (M2) and the DEBUG demo source,
/// so the UI cannot tell them apart and no parallel model can drift.
protocol ConditionsProviding: Sendable {
    /// `true` when the values are sample data. Release providers must return
    /// `false`; only `DemoConditionsProvider` returns `true`.
    var isSampleData: Bool { get }

    /// Conditions at one instant.
    func conditions(for spot: Spot, at date: Date) async throws -> Conditions

    /// Hourly conditions starting at `date`, `hours` samples long.
    func forecast(for spot: Spot, from date: Date, hours: Int) async throws -> [Conditions]
}

enum ConditionsProviderError: Error, Equatable {
    case tideUnavailable
    case weatherUnavailable
    case marineUnavailable

    /// Short French detail shown under the « Données indisponibles » verdict.
    var displayMessage: String {
        switch self {
        case .tideUnavailable:
            "La marée n'est pas disponible pour ce spot."
        case .weatherUnavailable:
            "La météo n'est pas encore disponible pour ce spot."
        case .marineUnavailable:
            "La houle et la température de l'eau ne sont pas disponibles pour ce spot."
        }
    }
}
