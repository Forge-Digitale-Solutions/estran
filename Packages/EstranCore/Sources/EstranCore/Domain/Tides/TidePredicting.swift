import Foundation

/// Produces a tide state for a station at a given instant.
///
/// Implementations must be deterministic: the same station and date always
/// produce the same state, with no network access and no ambient clock read.
public protocol TidePredicting: Sendable {
    func state(for station: TidalStation, at date: Date) async throws -> TideState
}
