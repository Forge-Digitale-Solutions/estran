@testable import Estran
import EstranCore
import XCTest

/// App Shortcuts phrases and entity catalog, without the Siri runtime.
final class IntentShortcutsTests: XCTestCase {
    func testAppShortcutsBuildWithFrenchTitlesAndSymbols() {
        let shortcuts = EstranShortcuts.appShortcuts

        XCTAssertEqual(shortcuts.count, 4)
        XCTAssertFalse(EstranShortcuts.phraseTemplates.isEmpty)
        XCTAssertTrue(
            EstranShortcuts.phraseTemplates.contains {
                $0.contains("applicationName")
            })
        XCTAssertTrue(
            EstranShortcuts.phraseTemplates.contains {
                $0.contains("bon moment")
            })
    }

    func testPhraseTemplatesAllMentionApplicationName() {
        for phrase in EstranShortcuts.phraseTemplates {
            XCTAssertTrue(
                phrase.contains("applicationName"),
                "Chaque phrase doit inclure .applicationName : \(phrase)")
        }
    }

    func testSpotEntitiesAreExactlyTheTwoCatalogSpots() {
        XCTAssertEqual(SpotEntity.all.map(\.id), SpotCatalog.v1.map(\.id))
        XCTAssertEqual(SpotEntity.all.count, 2)
        XCTAssertEqual(SpotEntity.pointeDeGrave.name, "Pointe de Grave")
        XCTAssertEqual(SpotEntity.arcachonEyrac.name, "Arcachon-Eyrac")
    }

    func testActivityEntitiesCoverTheFiveActivities() {
        XCTAssertEqual(ActivityEntity.all.count, 5)
        XCTAssertEqual(
            Set(ActivityEntity.all.map(\.id)),
            Set(Activity.allCases.map(\.rawValue)))
        XCTAssertEqual(ActivityEntity.surfing.name, "Surf")
        XCTAssertEqual(ActivityEntity.swimming.name, "Baignade")
    }
}
