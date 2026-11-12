@testable import EstranCore
import XCTest

/// Per-spot activity copy and the boating caution, tested as pure strings.
final class ActivityOfferTests: XCTestCase {
    // MARK: - Not offered

    func testSurfIsNotOfferedAtEyrac() {
        XCTAssertFalse(SpotCatalog.arcachonEyrac.supports(.surfing))
        XCTAssertTrue(SpotCatalog.pointeDeGrave.supports(.surfing))
    }

    func testNotOfferedTitleNamesTheSpot() {
        XCTAssertEqual(
            ActivityOffer.notOfferedTitle(activity: .surfing, spot: SpotCatalog.arcachonEyrac),
            "Pas de surf à Arcachon-Eyrac")
    }

    func testNotOfferedDetailPointsToTheOceanSide() {
        XCTAssertEqual(
            ActivityOffer.notOfferedDetail(activity: .surfing),
            "Le surf, c'est côté océan : Cap Ferret ou la Salie.")
    }

    func testNotOfferedSentenceIsNeverOuiNonOrUnavailable() {
        let sentence = ActivityOffer.notOfferedSentence(
            activity: .surfing, spot: SpotCatalog.arcachonEyrac)

        XCTAssertFalse(sentence.contains("Oui"))
        XCTAssertFalse(sentence.contains("Non"))
        XCTAssertFalse(sentence.contains("Données indisponibles"))
        XCTAssertTrue(sentence.hasPrefix("Pas de surf à Arcachon-Eyrac."))
        XCTAssertTrue(sentence.contains("côté océan"))
    }

    // MARK: - Boating caution

    func testBoatingCautionAppliesOnlyToTheBassinSpot() {
        XCTAssertEqual(
            ActivityCaution.caution(activity: .boating, spot: SpotCatalog.arcachonEyrac),
            ActivityCaution.boatingPasses)
        XCTAssertNil(ActivityCaution.caution(activity: .boating, spot: SpotCatalog.pointeDeGrave))
        XCTAssertNil(ActivityCaution.caution(activity: .surfing, spot: SpotCatalog.arcachonEyrac))
    }

    func testBoatingCautionIsCopyAndNeverReachesTheRule() {
        // The caution is a string attached to the boating surfaces, not an
        // input to `BoatingRule`: it has no blocker and no score term, so it
        // can never turn the verdict. Assert the copy carries the two facts.
        XCTAssertTrue(ActivityCaution.boatingPasses.contains("passes du Bassin"))
        XCTAssertTrue(ActivityCaution.boatingPasses.contains("houle de l'océan"))
        XCTAssertTrue(ActivityCaution.boatingPasses.contains("bancs qui bougent"))
    }
}
