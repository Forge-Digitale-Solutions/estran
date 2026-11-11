import Foundation

#if canImport(FoundationModels)
    import FoundationModels

    /// Constrained on-device draft for the reason sentence.
    ///
    /// `@Generable` / `@Guide` force a single French field through the
    /// Foundation Models schema; `FoundationModelReasonProvider.isAcceptable`
    /// remains the safety net for invariants the schema cannot encode
    /// (no « Oui » for swimming, no SHOM, no invented digits).
    ///
    /// Uses `@Generable(description:)` (iOS 26+). The iOS 27
    /// `@Generable(name:description:)` overload expands to a
    /// `GenerationSchema(name:…)` call that does not match the on-disk SDK
    /// (`type:description:properties:`), so the named form is skipped.
    @available(iOS 26.0, *)
    @Generable(description: "Explication courte du verdict Estran en français (tutoiement).")
    struct ReasonDraft {
        /// One short French sentence; length and voice are guided, then re-checked.
        @Guide(
            description: """
            Une seule phrase factuelle en français, tutoiement, 12 mots maximum, \
            160 caractères maximum. Pas de salutation, pas d'emoji, pas d'exclamation. \
            N'invente aucun chiffre. Ne dis jamais que la donnée est officielle.
            """)
        var sentence: String
    }
#endif
