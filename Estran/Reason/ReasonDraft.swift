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
    @Generable(description: "Phrase complète du verdict Estran en français, avec verbe conjugué.")
    struct ReasonDraft {
        /// One short French sentence; length and voice are guided, then re-checked.
        @Guide(
            description: """
            Une seule phrase complète en français avec un verbe conjugué \
            (est, reste, manque, souffle…). Tutoiement seulement pour parler \
            à l'utilisateur (« Ta marge est trop faible… »), sinon neutre \
            (« La marge est trop faible… »). 12 mots maximum, 140 caractères \
            maximum. Pas de fragment possessif sans verbe, pas de salutation, \
            pas d'emoji, pas d'exclamation. N'invente aucun chiffre. Ne cite \
            jamais SHOM ni une donnée officielle. Jamais « Oui » pour la baignade. \
            La phrase explique le verdict du contexte et ne le contredit jamais ; \
            recopie le nom du spot exactement, majuscule comprise.
            """)
        var sentence: String
    }
#endif
