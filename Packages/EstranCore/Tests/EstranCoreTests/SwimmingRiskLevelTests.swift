@testable import EstranCore
import XCTest

/// Swimming is a **risk level, never a verdict**. These tests pin the mapping
/// and the warning text that every surface (app, widget, Live Activity, Siri)
/// must share.
final class SwimmingRiskLevelTests: XCTestCase {
    private func decision(
        go: Bool = false,
        blockers: [ActivityBlocker] = []) -> GoDecision
    {
        GoDecision(
            activity: .swimming,
            spot: SpotCatalog.arcachonEyrac,
            go: go,
            score: go ? 0.9 : 0.2,
            reason: "test",
            reasonSource: .template,
            nextGoodWindow: nil,
            computedAt: Date(timeIntervalSince1970: 0),
            blockers: blockers)
    }

    func testUnavailableDataIsNeverALowCurrent() {
        XCTAssertEqual(
            SwimmingRiskLevel(decision: decision(blockers: [.currentDataUnavailable])),
            .unknown)
        // The current gap wins even when another blocker is present.
        XCTAssertEqual(
            SwimmingRiskLevel(
                decision: decision(blockers: [.currentDataUnavailable, .strongCurrent])),
            .unknown)
    }

    func testMissingSeaTemperatureDoesNotMuteTheCurrentLevel() {
        let advisory = SwimmingAdvisory(
            decision: decision(blockers: [.dataUnavailable]),
            conditions: conditions(water: nil))
        XCTAssertEqual(advisory.level, .low)
        XCTAssertTrue(advisory.conditionsLine?.contains("eau indisponible") == true)
    }

    func testStrongCurrentAndMarginMapToTheirLevels() {
        XCTAssertEqual(
            SwimmingRiskLevel(decision: decision(blockers: [.strongCurrent])),
            .strong)
        XCTAssertEqual(
            SwimmingRiskLevel(decision: decision(blockers: [.insufficientMargin])),
            .moderate)
    }

    func testACleanDecisionIsLowButStillNotAOui() {
        let level = SwimmingRiskLevel(decision: decision(go: true))
        XCTAssertEqual(level, .low)
        XCTAssertEqual(level.title, "Courants estimés faibles")
        for level in SwimmingRiskLevel.allCases {
            XCTAssertFalse(level.title.contains("Oui"))
            XCTAssertFalse(level.title.contains("Non"))
            XCTAssertFalse(level.label.contains("Oui"))
            XCTAssertFalse(level.label.contains("Non"))
        }
    }

    func testBassinWarningNamesBainesTidalCurrentsAndTheDisclaimer() {
        let warning = SwimmingRiskLevel.moderate.warning(for: .bassin)
        // Baïnes are a Bassin hazard too, not only an ocean one, all year.
        XCTAssertTrue(warning.contains("Toute l'année"))
        XCTAssertTrue(warning.contains("baïnes"))
        XCTAssertTrue(warning.contains("courants de marée"))
        XCTAssertTrue(warning.contains("zone surveillée"))
        XCTAssertTrue(warning.contains(SwimmingRiskLevel.escape))
        XCTAssertTrue(warning.contains(SwimmingRiskLevel.disclaimer))
    }

    func testOceanWarningNamesBainesFlagsAndTheEscape() {
        let warning = SwimmingRiskLevel.strong.warning(for: .medoc)
        XCTAssertTrue(warning.contains("Toute l'année"))
        XCTAssertTrue(warning.contains("baïnes"))
        XCTAssertTrue(warning.contains("drapeaux"))
        XCTAssertTrue(warning.contains("nage parallèle"))
        XCTAssertTrue(warning.contains(SwimmingRiskLevel.escape))
        XCTAssertTrue(warning.contains(SwimmingRiskLevel.disclaimer))
    }

    func testDisclaimerDoesNotClaimToDetectBaines() {
        XCTAssertTrue(SwimmingRiskLevel.disclaimer.contains("courants de marée"))
        XCTAssertTrue(SwimmingRiskLevel.disclaimer.contains("ni les baïnes"))
    }

    func testWidgetWarningStaysShortButKeepsTheHazard() {
        XCTAssertTrue(
            SwimmingRiskLevel.low.widgetWarning(for: .bassin).contains("baïnes"))
        XCTAssertTrue(
            SwimmingRiskLevel.low.widgetWarning(for: .medoc).contains("baïnes"))
        XCTAssertTrue(
            SwimmingRiskLevel.low.widgetWarning(for: .medoc)
                .contains("nage parallèle"))
    }

    func testLevelSurvivesCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(SwimmingRiskLevel.strong)
        XCTAssertEqual(
            try JSONDecoder().decode(SwimmingRiskLevel.self, from: data),
            .strong)
    }

    // MARK: Z31 — conditions line and non-current blockers

    private func conditions(
        windSpeed: Double = 12,
        waveHeight: Double = 0.6,
        water: Double? = 19) -> Conditions
    {
        let date = Date(timeIntervalSince1970: 0)
        return DecisionFixtures.conditions(
            at: date,
            tide: DecisionFixtures.tide(at: date),
            weather: DecisionFixtures.weather(windSpeed: windSpeed),
            swell: DecisionFixtures.swell(
                waveHeight: waveHeight,
                seaSurfaceTemperature: water))
    }

    func testConditionsLineFormatsWindSwellAndWaterInFrench() {
        let line = SwimmingAdvisory.conditionsLine(
            for: conditions(windSpeed: 38, waveHeight: 1.5, water: 17))
        XCTAssertEqual(line, "Vent 38 km/h · houle 1,5 m · eau 17 °C")
    }

    func testConditionsLineNeverInventsAWaterTemperature() {
        let line = SwimmingAdvisory.conditionsLine(
            for: conditions(waveHeight: 0.6, water: nil))
        XCTAssertTrue(line.contains("eau indisponible"))
    }

    func testWindAloneIsANoteAndNeverAOui() {
        let advisory = SwimmingAdvisory(
            decision: decision(blockers: [.wind]),
            conditions: conditions(windSpeed: 38, waveHeight: 1.5, water: 17))
        XCTAssertEqual(advisory.level, .low, "the level stays about currents")
        XCTAssertEqual(advisory.notes, ["vent fort"])
        XCTAssertTrue(advisory.accessibilitySentence.lowercased().contains("vent"))
        XCTAssertFalse(advisory.accessibilitySentence.contains("Oui"))
        XCTAssertFalse(advisory.warning.contains("Oui"))
    }

    func testNonCurrentBlockersAreNamedOnceEach() {
        let advisory = SwimmingAdvisory(
            decision: decision(blockers: [.wind, .swellTooLarge, .waterTemperature]),
            conditions: conditions())
        XCTAssertEqual(advisory.notes, ["vent fort", "houle trop forte", "eau froide"])
    }

    func testStrongCurrentStaysInTheLevelAndNotInTheNotes() {
        let advisory = SwimmingAdvisory(
            decision: decision(blockers: [.strongCurrent]),
            conditions: conditions())
        XCTAssertEqual(advisory.level, .strong)
        XCTAssertTrue(advisory.notes.isEmpty)
    }

    func testUnavailableDataKeepsTheUnknownLevelWithoutANote() {
        let advisory = SwimmingAdvisory(
            decision: decision(blockers: [.currentDataUnavailable]),
            conditions: conditions(water: nil))
        XCTAssertEqual(advisory.level, .unknown)
        XCTAssertTrue(advisory.notes.isEmpty)
    }

    func testAccessibilitySentencePutsTheWarningBeforeTheLevel() {
        let advisory = SwimmingAdvisory(
            decision: decision(blockers: [.wind]),
            conditions: conditions(windSpeed: 38))
        let sentence = advisory.accessibilitySentence
        let warningIndex = sentence.range(of: "Toute l'année")?.lowerBound
        let levelIndex = sentence.range(of: advisory.level.label)?.lowerBound
        XCTAssertNotNil(warningIndex)
        XCTAssertNotNil(levelIndex)
        if let warningIndex, let levelIndex {
            XCTAssertLessThan(warningIndex, levelIndex)
        }
    }

    func testLevelLabelIsExplicitAndTheShortFormIsOneWord() {
        XCTAssertEqual(
            SwimmingRiskLevel.low.label,
            "Courants de marée estimés : faibles")
        XCTAssertEqual(SwimmingRiskLevel.low.shortTitle, "faibles")
        XCTAssertEqual(SwimmingRiskLevel.unknown.shortTitle, "non estimés")
    }

    func testAccessibilitySentenceCapitalizesTheFirstNote() {
        let advisory = SwimmingAdvisory(
            decision: decision(blockers: [.wind]),
            conditions: conditions(windSpeed: 38))
        XCTAssertTrue(advisory.accessibilitySentence.contains("Vent fort"))
        XCTAssertFalse(advisory.accessibilitySentence.contains(". vent fort"))
    }

    func testEveryBlockerHasAnExplicitSwimmingNoteOrIsCurrentRelated() {
        let expected: [ActivityBlocker: String?] = [
            .storm: "orage",
            .dataUnavailable: nil,
            .currentDataUnavailable: nil,
            .rain: "pluie",
            .wind: "vent fort",
            .coefficient: nil,
            .tideTiming: nil,
            .waveTooSmall: "mer trop plate",
            .waveTooLarge: "houle trop forte",
            .wavePeriod: "période de houle inadaptée",
            .swellTooLarge: "houle trop forte",
            .swellDirection: "houle mal orientée",
            .onshoreWind: "vent onshore",
            .fog: "brouillard",
            .visibility: "visibilité insuffisante",
            .waterLevel: nil,
            .waterTemperature: "eau froide",
            .temperature: "air froid",
            .night: "la nuit",
            .strongCurrent: nil,
            .insufficientMargin: nil
        ]
        XCTAssertEqual(Set(expected.keys), Set(ActivityBlocker.allCases))
        for blocker in ActivityBlocker.allCases {
            let note = expected[blocker].flatMap(\.self)
            XCTAssertEqual(
                SwimmingAdvisory.notes(for: [blocker]),
                note.map { [$0] } ?? [],
                "unexpected note for \(blocker)")
        }
    }

    func testAdvisorySurvivesCodableRoundTripForTheLiveActivity() throws {
        let advisory = SwimmingAdvisory(
            decision: decision(blockers: [.wind]),
            conditions: conditions(windSpeed: 38))
        let data = try JSONEncoder().encode(advisory)
        XCTAssertEqual(
            try JSONDecoder().decode(SwimmingAdvisory.self, from: data),
            advisory)
    }
}
