import EstranCore

/// Whether the Open-Meteo Marine grid describes the water at a spot.
///
/// The model is a **global offshore wave grid** (≈ 0.08° at best): it resolves
/// the open Atlantic, not a 20 km lagoon. Measured on 2026-10-28: at the Eyrac
/// jetty, inside the Bassin, it returns 2.5 m / 11 s / 285° — open-ocean swell,
/// not the water at the jetty. Using it there would block surf for the wrong
/// reason and paint a sea that does not exist.
///
/// This is a **data-sourcing decision, not a rule**: the rules already know how
/// to fail closed, they only need to be told the wave data is missing. When the
/// catalog gains a `waveSource` field (next dataset revision), this enum moves
/// into `Spot` and disappears from the app layer.
enum MarinePolicy {
    /// The spot sits on the open coast, inside the model's grid.
    case offshoreModel
    /// The model does not describe this water. Wave-dependent activities are
    /// « Données indisponibles », never a guessed sea.
    case unavailable

    static func source(for spot: Spot) -> MarinePolicy {
        switch spot.region {
        case .medoc: .offshoreModel
        case .bassin: .unavailable
        }
    }
}
