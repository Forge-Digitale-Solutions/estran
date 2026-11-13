@testable import Estran
import EstranCore
import XCTest

/// W-ATTR — the weather credit is data, so it is tested as data.
///
/// Apple WeatherKit's terms require the mark and the legal page wherever its
/// data appears; Open-Meteo requires a CC BY 4.0 credit. The bug this guards
/// against is a wrong or missing credit: Apple's mark over Open-Meteo values,
/// a credit for sample data, or a broken image when the mark cannot be fetched.
final class WeatherAttributionTests: XCTestCase {
    private static let attribution = AppleWeatherAttribution(
        serviceName: "Apple Météo",
        markURL: fixtureURL("https://weatherkit.apple.com/mark-dark.png"),
        legalPageURL: fixtureURL("https://weatherkit.apple.com/legal-attribution"))

    private static func fixtureURL(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            fatalError("Malformed fixture URL: \(string)")
        }
        return url
    }

    // MARK: - Source record

    @MainActor
    func testSourceIsRecordedPerSpot() {
        let store = WeatherAttributionStore(
            attributionLoader: { Self.attribution },
            markDownloader: { _ in Data([1]) },
            recordContainer: nil)

        store.record(.appleWeather, forSpotID: SpotCatalog.pointeDeGrave.id)
        store.record(.openMeteo, forSpotID: SpotCatalog.arcachonEyrac.id)

        XCTAssertEqual(store.source(forSpotID: SpotCatalog.pointeDeGrave.id), .appleWeather)
        XCTAssertEqual(store.source(forSpotID: SpotCatalog.arcachonEyrac.id), .openMeteo)
        XCTAssertNil(store.source(forSpotID: "unknown-spot"))
    }

    @MainActor
    func testSampleDataCreditsNobody() {
        let store = WeatherAttributionStore(
            attributionLoader: { Self.attribution },
            markDownloader: { _ in Data([1]) },
            recordContainer: nil)

        store.record(.openMeteo, forSpotID: SpotCatalog.pointeDeGrave.id)
        store.record(nil, forSpotID: SpotCatalog.pointeDeGrave.id)

        XCTAssertNil(store.source(forSpotID: SpotCatalog.pointeDeGrave.id))
    }

    /// The widget reads the same file: a record written for one spot must not
    /// leak into the other, and removing one must leave the other alone.
    func testRecordFileRoundTrip() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        WeatherSourceRecord.save(.appleWeather, forSpotID: "a", in: directory)
        WeatherSourceRecord.save(.openMeteo, forSpotID: "b", in: directory)

        XCTAssertEqual(WeatherSourceRecord.load(forSpotID: "a", from: directory), .appleWeather)
        XCTAssertEqual(WeatherSourceRecord.load(forSpotID: "b", from: directory), .openMeteo)

        WeatherSourceRecord.remove(forSpotID: "a", in: directory)
        XCTAssertNil(WeatherSourceRecord.load(forSpotID: "a", from: directory))
        XCTAssertEqual(WeatherSourceRecord.load(forSpotID: "b", from: directory), .openMeteo)
    }

    func testMissingRecordIsUnknownNotADefault() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        XCTAssertNil(WeatherSourceRecord.load(forSpotID: "anything", from: directory))
    }

    // MARK: - Apple mark

    @MainActor
    func testMarkAndLegalPageLoadOnce() async {
        let calls = LockedCounter()
        let store = WeatherAttributionStore(
            attributionLoader: {
                calls.increment()
                return Self.attribution
            },
            markDownloader: { _ in Data([0x89, 0x50]) },
            recordContainer: nil)

        await store.loadAppleAttributionIfNeeded()
        await store.loadAppleAttributionIfNeeded()

        XCTAssertEqual(store.mark, .loaded(Self.attribution))
        XCTAssertEqual(store.markImageData, Data([0x89, 0x50]))
        XCTAssertEqual(store.legalPageURL, Self.attribution.legalPageURL)
        XCTAssertEqual(calls.value, 1, "the attribution endpoint is asked once per process")
    }

    /// A failed attribution call leaves neither a mark nor a link: the views
    /// fall back to the text « Météo : Apple Météo » and draw no broken image.
    @MainActor
    func testFailedAttributionCallIsUnavailable() async {
        let store = WeatherAttributionStore(
            attributionLoader: { throw WeatherAttributionError.unavailable },
            markDownloader: { _ in Data([1]) },
            recordContainer: nil)

        await store.loadAppleAttributionIfNeeded()

        XCTAssertEqual(store.mark, .unavailable)
        XCTAssertNil(store.markImageData)
        XCTAssertNil(store.legalPageURL)
    }

    /// The attribution can answer while the image does not: the credit keeps
    /// its legal link and loses only the picture.
    @MainActor
    func testFailedMarkDownloadKeepsTheLegalPage() async {
        let store = WeatherAttributionStore(
            attributionLoader: { Self.attribution },
            markDownloader: { _ in throw WeatherAttributionError.unavailable },
            recordContainer: nil)

        await store.loadAppleAttributionIfNeeded()

        XCTAssertEqual(store.mark, .loaded(Self.attribution))
        XCTAssertNil(store.markImageData)
        XCTAssertEqual(store.legalPageURL, Self.attribution.legalPageURL)
    }

    // MARK: - Glossary

    /// The glossary is a product requirement, not decoration: every indicator
    /// the screens use has an entry, including the two absences (the
    /// coefficient and a swimming verdict) that must stay explained.
    func testGlossaryCoversTheIndicators() {
        let terms = IndicatorGlossaryEntry.all.map(\.term)
        for expected in [
            "Marée",
            "Marnage, grande et petite marée",
            "Houle",
            "Vent",
            "Météo",
            "Coefficient",
            "Baignade",
            "Créneau",
            "Données indisponibles"
        ] {
            XCTAssertTrue(terms.contains(expected), "Missing glossary entry: \(expected)")
        }
        XCTAssertTrue(
            IndicatorGlossaryEntry.all.allSatisfy { !$0.detail.isEmpty },
            "A glossary entry without an explanation is a heading, not a glossary")
    }

    func testOpenMeteoIsCreditedWithItsLicence() {
        XCTAssertEqual(WeatherSourceKind.appleWeather.displayName, "Apple Météo")
        XCTAssertEqual(WeatherSourceKind.openMeteo.displayName, "Open-Meteo")
        XCTAssertEqual(WeatherSourceKind.openMeteo.licenceLine, "CC BY 4.0")
    }
}

/// A counter the `@Sendable` loaders can bump from another executor.
private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}
