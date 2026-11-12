import EstranCore
import Foundation

extension FoundationModelReasonProvider {
    // MARK: - Output validation

    /// Whether a generated sentence may replace the template.
    ///
    /// Anything doubtful is rejected: the template is complete, so a rejection
    /// costs nothing. This is where the invariants are enforced on generated
    /// text. Both checks below compare sets, never substrings: a number must be
    /// one the prompt carried (« 2 » cannot pass on « 1,2 m »), and a swimming
    /// sentence may not offer the water at all. A fragment without a conjugated
    /// verb (« Ta marge insuffisante… ») also fails closed to the template.
    static func isAcceptable(_ text: String, for decision: GoDecision, conditions: Conditions) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maximumCharacters,
              trimmed.split(whereSeparator: \.isWhitespace).count <= maximumWords, !containsEmoji(trimmed),
              !claimsOfficiality(trimmed), hasConjugatedVerb(trimmed)
        else {
            return false
        }
        // Invariant 1: no `Oui` for swimming, and none for a `Non` verdict.
        if decision.activity == .swimming || !decision.go {
            guard !containsWord("oui", in: trimmed) else { return false }
        }
        if decision.activity == .swimming, offersASwim(trimmed) {
            return false
        }
        if !decision.go, trimmed.lowercased().contains("c'est bon") {
            return false
        }
        // Invariant 3: a number absent from the values the prompt carried is an
        // invention. Set comparison: « 2 » is not « 1,2 ».
        let allowed = promptNumbers(for: decision, conditions: conditions)
        return numericValues(in: trimmed).isSubset(of: allowed)
    }

    /// Cheap grammar gate: at least one common conjugated French verb.
    ///
    /// Catches possessive fragments such as « Ta marge insuffisante… » that
    /// lack a verb. Over-rejection only costs the deterministic template.
    private static let conjugatedVerbForms = [
        "est", "sont", "reste", "restent", "manque", "dépasse", "empêche",
        "faut", "peux", "permet", "souffle", "monte", "descend"
    ]

    private static func hasConjugatedVerb(_ text: String) -> Bool {
        let lowered = text
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .lowercased()
        return conjugatedVerbForms.contains { verb in
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: verb))\\b"
            return lowered.range(of: pattern, options: .regularExpression) != nil
        }
    }

    /// Invariant 1, wording: a swimming sentence never invites you into the
    /// water.
    ///
    /// Safety rule, not style: the swimming verdict is a risk level and the app
    /// cannot see baïnes or lifeguards. Telling a positive construction from a
    /// negated one in one short sentence is unreliable, so the whole family is
    /// banned: any « baign- » stem (baigner, se baigner, baignade), any form of
    /// « pouvoir » (tu peux, on peut, tu pourras), any form of « profiter »
    /// and « c'est bon ». Over-rejection only costs the safe template.
    private static func offersASwim(_ text: String) -> Bool {
        let lowered = text.replacingOccurrences(of: "\u{2019}", with: "'").lowercased()
        let patterns = [
            "baign", "c'est\\s+bon",
            "\\b(?:pouvoir|peux|peut|peuvent|pouvons|pouvez|pourra|pourras|pourrez"
                + "|pourrais|pourriez|pouvait|pouvaient|pu)\\b",
            "\\bprofit\\w*"
        ]
        return patterns.contains { lowered.range(of: $0, options: .regularExpression) != nil }
    }

    private static func containsWord(_ word: String, in text: String) -> Bool {
        text.range(
            of: "\\b\(word)\\b",
            options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func containsEmoji(_ text: String) -> Bool {
        text.range(
            of: "[\u{1F000}-\u{1FAFF}\u{2190}-\u{27BF}\u{FE0F}]",
            options: .regularExpression) != nil
    }

    /// Invariant 2: the text never claims SHOM officiality or a local measure.
    private static func claimsOfficiality(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return ["shom", "officiel", "mesure locale", "mesuré sur place", "mesurée sur place"]
            .contains { lowered.contains($0) }
    }

    /// Every number the prompt carried, from its structured inputs only: the
    /// activity, the verdict, the blockers, the nearest tide event (local time
    /// and height), the wind, the swell and the water temperature. The
    /// instructions' prose is not a source: « 12 mots maximum » is a
    /// constraint, not a datum.
    private static func promptNumbers(for decision: GoDecision, conditions: Conditions) -> Set<Decimal> {
        var sources = [
            decision.activity.displayNameWithArticle,
            verdict(for: decision),
            blockerLine(for: decision.blockers),
            "\(rounded(conditions.weather.wind.speed))",
            decimal(conditions.swell.waveHeight, digits: 1)
        ]
        if let water = conditions.swell.seaSurfaceTemperature {
            sources.append("\(rounded(water))")
        }
        if let tide = tideEvent(for: conditions) {
            sources.append(clockTime(tide.time, in: conditions.spot.timezone))
            sources.append(decimal(tide.height, digits: 2))
        }
        return sources.reduce(into: Set<Decimal>()) { $0.formUnion(numericValues(in: $1)) }
    }

    /// Canonical value of every number in `text`: comma or dot decimals, a
    /// leading zero ignored, the unit dropped. « 14h20 » gives 14 and 20.
    private static func numericValues(in text: String) -> Set<Decimal> {
        guard let regex = try? NSRegularExpression(pattern: "\\d+(?:[.,]\\d+)?") else { return [] }
        let source = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: source.length))
            .reduce(into: Set<Decimal>()) { values, match in
                let token = source.substring(with: match.range).replacingOccurrences(of: ",", with: ".")
                if let value = Decimal(string: token, locale: Locale(identifier: "en_US_POSIX")) {
                    values.insert(value)
                }
            }
    }
}
