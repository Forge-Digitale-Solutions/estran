@testable import Estran
import EstranCore
import XCTest

/// The Siri/Shortcuts mapping, tested without the App Intents runtime: every
/// state the snapshot can hold has one and only one sentence, and swimming can
/// never read as a permission.
final class IntentAnswerTests: XCTestCase {
    // MARK: - Missing data

    func testNilSnapshotAsksToOpenTheApp() {
        XCTAssertEqual(
            IntentAnswer.text(for: nil),
            "Ouvre Estran pour charger les conditions.")
    }

    func testUnavailableSnapshotNamesTheSpot() {
        let snapshot = makeSnapshot(isUnavailable: true, answer: "Données indisponibles")

        let text = IntentAnswer.text(for: snapshot)

        XCTAssertEqual(text, "Données indisponibles pour Pointe de Grave.")
        XCTAssertTrue(text.contains("Données indisponibles"))
    }

    func testUnavailableSwimmingIsStillUnavailableAndNeverOui() {
        let snapshot = makeSnapshot(
            activity: .swimming,
            isUnavailable: true,
            answer: "Données indisponibles")

        let text = IntentAnswer.text(for: snapshot)

        XCTAssertEqual(text, "Données indisponibles pour Pointe de Grave.")
        XCTAssertTrue(text.contains("Données indisponibles"))
        XCTAssertFalse(text.contains("Oui"))
    }

    // MARK: - Pêche à pied

    func testGoAnswersOuiThenTheWindow() {
        let snapshot = makeSnapshot(isGo: true, answer: "13 h 10 à 15 h 40")

        XCTAssertEqual(
            IntentAnswer.text(for: snapshot),
            "Oui à Pointe de Grave : 13 h 10 à 15 h 40.")
    }

    func testGoStripsATrailingPeriodFromTheSnapshotPhrase() {
        let snapshot = makeSnapshot(isGo: true, answer: "Marge suffisante.")

        XCTAssertEqual(
            IntentAnswer.text(for: snapshot),
            "Oui à Pointe de Grave : Marge suffisante.")
    }

    func testNoGoAnswersNonThenTheReason() {
        let snapshot = makeSnapshot(isGo: false, answer: "Vent fort")

        XCTAssertEqual(
            IntentAnswer.text(for: snapshot),
            "Non à Pointe de Grave : Vent fort.")
    }

    func testTheAnswerUsesTheSnapshotSpotRatherThanAFixedOne() {
        let snapshot = makeSnapshot(
            spotID: "arcachon-eyrac",
            spotName: "Arcachon-Eyrac",
            isGo: true,
            answer: "Dès 17 h")

        XCTAssertEqual(
            IntentAnswer.text(for: snapshot),
            "Oui à Arcachon-Eyrac : Dès 17 h.")
    }

    // MARK: - Baignade

    func testSwimmingSpeaksTheLevelAndTheWarning() {
        let snapshot = makeSnapshot(
            activity: .swimming,
            isGo: false,
            answer: "Courants de marée estimés : forts",
            swimmingAdvisory: SwimmingAdvisory(level: .strong, region: .medoc))

        let text = IntentAnswer.text(for: snapshot)

        XCTAssertTrue(text.contains("Courants de marée estimés : forts"))
        XCTAssertTrue(text.contains(SwimmingRiskLevel.strong.warning(for: .medoc)))
        XCTAssertTrue(text.contains("Toute l'année"))
    }

    func testSwimmingNeverSaysOuiEvenWhenTheCurrentsAreLow() {
        let snapshot = makeSnapshot(
            activity: .swimming,
            isGo: true,
            answer: "Courants de marée estimés : faibles",
            swimmingAdvisory: SwimmingAdvisory(level: .low, region: .bassin))

        let text = IntentAnswer.text(for: snapshot)

        XCTAssertFalse(text.contains("Oui"))
        XCTAssertTrue(text.contains("Courants de marée estimés : faibles"))
        XCTAssertTrue(text.contains(SwimmingRiskLevel.disclaimer))
    }

    func testSwimmingWithoutAnAdvisoryStillWarnsAndNeverSaysOui() {
        let snapshot = makeSnapshot(activity: .swimming, isGo: false, answer: "")

        let text = IntentAnswer.text(for: snapshot)

        XCTAssertFalse(text.contains("Oui"))
        XCTAssertTrue(text.contains("Courants de marée non estimés"))
        XCTAssertTrue(text.contains("Toute l'année"))
        XCTAssertTrue(text.contains(SwimmingRiskLevel.disclaimer))
    }

    func testAnswerIntentDialogForSwimmingNeverSaysOui() {
        let snapshot = makeSnapshot(
            activity: .swimming,
            isGo: true,
            answer: "Courants de marée estimés : faibles",
            swimmingAdvisory: SwimmingAdvisory(level: .low, region: .medoc))
        let intent = AnswerIntent(activity: .swimming)

        let text = intent.resolvedText(for: snapshot)

        XCTAssertFalse(text.contains("Oui"))
        XCTAssertTrue(text.contains("Baignade"))
    }

    // MARK: - Staleness

    func testAStaleSnapshotIsAnnouncedBeforeTheAnswer() {
        let old = Date().addingTimeInterval(-(WidgetSnapshot.staleAfter + 60))
        let snapshot = makeSnapshot(
            updatedAt: old,
            isGo: true,
            answer: "13 h 10 à 15 h 40")

        XCTAssertEqual(
            IntentAnswer.text(for: snapshot),
            "Ces données datent de plus de deux heures. "
                + "Oui à Pointe de Grave : 13 h 10 à 15 h 40.")
    }

    func testAFreshSnapshotIsNotAnnouncedAsStale() {
        let snapshot = makeSnapshot(isGo: false, answer: "Houle trop forte")

        XCTAssertFalse(IntentAnswer.text(for: snapshot).contains("plus de deux heures"))
    }

    func testAStaleSwimmingAnswerKeepsTheWarning() {
        let old = Date().addingTimeInterval(-(WidgetSnapshot.staleAfter + 60))
        let snapshot = makeSnapshot(
            updatedAt: old,
            activity: .swimming,
            isGo: false,
            answer: "Courants de marée estimés : modérés",
            swimmingAdvisory: SwimmingAdvisory(level: .moderate, region: .medoc))

        let text = IntentAnswer.text(for: snapshot)

        XCTAssertTrue(text.hasPrefix("Ces données datent de plus de deux heures. "))
        XCTAssertFalse(text.contains("Oui"))
        XCTAssertTrue(text.contains(SwimmingRiskLevel.disclaimer))
    }

    // MARK: - Wrong combination

    func testACombinationTheSnapshotDoesNotCoverIsAnnouncedNotAnswered() {
        let text = IntentAnswer.notReady(spot: "Arcachon-Eyrac", activity: .surfing)

        XCTAssertEqual(
            text,
            "Les données ne sont pas encore prêtes pour Surf à Arcachon-Eyrac. "
                + "Ouvre Estran pour charger les conditions.")
        XCTAssertFalse(text.contains("Oui"))
    }

    // MARK: - Fixtures

    private func makeSnapshot(
        updatedAt: Date = Date(),
        spotID: String = "pointe-de-grave",
        spotName: String = "Pointe de Grave",
        activity: Activity = .shoreFishing,
        isGo: Bool = false,
        isUnavailable: Bool = false,
        answer: String,
        swimmingAdvisory: SwimmingAdvisory? = nil) -> WidgetSnapshot
    {
        WidgetSnapshot(
            updatedAt: updatedAt,
            spotID: spotID,
            spotName: spotName,
            activity: activity,
            isGo: isGo,
            isUnavailable: isUnavailable,
            answer: answer,
            swimmingAdvisory: swimmingAdvisory)
    }
}
