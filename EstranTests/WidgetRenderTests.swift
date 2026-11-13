@testable import Estran
import EstranCore
import SwiftUI
import WidgetKit
import XCTest

/// W-WIDGETCONF — renders the configured widgets to PNG so the configured
/// spot + activity can be seen without adding the widget to a Home Screen.
///
/// The widget views and theme are compiled into this test target (see
/// `project.yml`); the entries are built through `GoEntry.make`, the same path
/// the timeline provider uses, so the image is exactly what the widget draws.
final class WidgetRenderTests: XCTestCase {
    /// `true` while the render target exists, so the PNGs land somewhere the
    /// integrator can copy out of the app container.
    private var renderDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("wconf", isDirectory: true)
    }

    @MainActor
    func testRenderConfiguredWidgets() throws {
        let directory = renderDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        try render(
            entry: GoEntry.make(
                snapshot: Self.eyracSnapshot, spot: SpotCatalog.arcachonEyrac, activity: .shoreFishing),
            to: directory.appendingPathComponent("wconf-arcachon-peche.png"))

        try render(
            entry: GoEntry.make(
                snapshot: Self.pointeSnapshot, spot: SpotCatalog.pointeDeGrave, activity: .surfing),
            to: directory.appendingPathComponent("wconf-pointe-de-grave-surf.png"))

        // W-LOCK: the four metric pills must name themselves (« Marée »,
        // « Vent », « Houle », « Météo »). The snapshots above are timestamped
        // in the past, so they render the stale card; these two use fresh
        // fixtures to show the pills.
        try render(
            entry: .sample,
            to: directory.appendingPathComponent("wlock-large-metrics.png"))
        try renderConditions(
            entry: .sample,
            to: directory.appendingPathComponent("wlock-conditions-metrics.png"))

        // W-ATTR: the weather credit under the conditions. A sample-data entry
        // credits nobody by design, so these fixtures flip the flag and name a
        // source, which is what the app writes for a live load.
        var appleCredit = GoEntry.sample
        appleCredit.isSampleData = false
        appleCredit.weatherSource = .appleWeather
        try render(
            entry: appleCredit,
            to: directory.appendingPathComponent("attr-widget-large-apple.png"))
        try renderConditions(
            entry: appleCredit,
            to: directory.appendingPathComponent("attr-widget-conditions-apple.png"))

        var openMeteoCredit = GoEntry.sample
        openMeteoCredit.isSampleData = false
        openMeteoCredit.weatherSource = .openMeteo
        try renderConditions(
            entry: openMeteoCredit,
            to: directory.appendingPathComponent("attr-widget-conditions-openmeteo.png"))

        print("WCONF_RENDER_DIR=\(directory.path)")
    }

    // MARK: - W-PILL: one height for the four metric pills

    /// The owner's real-device capture showed the HOULE pill taller than its
    /// three neighbours: « période 5 s » wrapped onto two lines in a ~74 pt
    /// pill. Every pill must now fit on the same three lines, at 5 s and at
    /// 11 s, and the fixed row must be tall enough to hold the tallest one.
    @MainActor
    func testLargeWidgetPillsShareOneHeightAtFiveAndElevenSeconds() throws {
        let directory = renderDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // 338 pt of large widget, 16 pt of content margin on each side and 4 pt
        // between the four pills: the width each pill really gets.
        let pillWidth = (338 - 2 * 16 - 3 * OceanSpacing.xxs) / 4

        for seconds in [5.0, 11.0] {
            let metrics = Self.largeMetrics(period: seconds)
            XCTAssertEqual(metrics.count, 4)

            let heights = metrics.map { metric in
                fittedHeight(of: WidgetMetricPill(metric: metric), width: pillWidth)
            }

            let tallest = try XCTUnwrap(heights.max())
            let shortest = try XCTUnwrap(heights.min())
            XCTAssertEqual(
                tallest, shortest, accuracy: 0.5,
                "the four pills must share one height at \(Int(seconds)) s: \(heights)")

            let rowHeight = fittedHeight(of: WidgetMetricsRow(metrics: metrics), width: 338)
            XCTAssertGreaterThanOrEqual(
                rowHeight, tallest,
                "the fixed row must hold its tallest pill, or the caption is clipped")

            try render(
                entry: Self.largeEntry(period: seconds),
                to: directory.appendingPathComponent("wpill-large-\(Int(seconds))s.png"))
        }
    }

    /// The laid-out height a view asks for at a given width, at `.large`.
    @MainActor
    private func fittedHeight(of view: some View, width: CGFloat) -> CGFloat {
        let host = UIHostingController(
            rootView: view
                .environment(\.widgetRenderingMode, .fullColor)
                .environment(\.dynamicTypeSize, .large)
                .frame(width: width))
        host.view.backgroundColor = .clear
        return host.sizeThatFits(
            in: CGSize(width: width, height: UIView.layoutFittingExpandedSize.height)).height
    }

    // MARK: - Rendering

    @MainActor
    private func render(entry: GoEntry, to url: URL) throws {
        let view = GoWidgetLargeView(entry: entry)
            .environment(\.widgetRenderingMode, .fullColor)
            .environment(\.dynamicTypeSize, .large)
            .frame(width: 338, height: 354)
            .background { WidgetOceanBackground() }

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: 338, height: 354)

        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw RenderError.couldNotRender
        }
        try data.write(to: url)
    }

    /// The Home Screen conditions card: four named pills in a 2 × 2 grid.
    @MainActor
    private func renderConditions(entry: GoEntry, to url: URL) throws {
        let view = ConditionsWidgetView(entry: entry)
            .environment(\.widgetRenderingMode, .fullColor)
            .environment(\.dynamicTypeSize, .large)
            .frame(width: 338, height: 158)
            // The pill fill is 10 % white, meant for the ocean backdrop: without
            // it the harness draws white glass on white and the values vanish.
            .background { WidgetOceanBackground() }

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: 338, height: 158)

        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw RenderError.couldNotRender
        }
        try data.write(to: url, options: .atomic)
    }

    private enum RenderError: Error {
        case couldNotRender
    }

    // MARK: - Fixtures

    private static let updatedAt = Date(timeIntervalSince1970: 1_793_000_000)

    /// The four conditions pills exactly as the app writes them, for a spot
    /// whose sea is measured: the swell caption is « période 5 s » (full) and
    /// « pér. 5 s » (compact), which is what the pill has to choose between.
    private static func largeMetrics(period: Double) -> [WidgetSnapshot.Metric] {
        let spot = SpotCatalog.pointeDeGrave
        let conditions = Conditions(
            spot: spot,
            at: updatedAt,
            tide: TideState(current: nil, next: nil, coefficient: 80, curve: []),
            weather: WeatherNow(
                temperature: 10,
                condition: .partlyCloudy,
                precipitationChance: 0,
                cloudCover: 0.3,
                wind: Wind(speed: 26, gust: 34, directionDegrees: 45),
                visibility: 20000),
            swell: Swell(
                waveHeight: 0.5,
                period: period,
                directionDegrees: 250,
                seaSurfaceTemperature: 11))
        return WidgetSnapshotBuilder.metrics(for: conditions)
    }

    /// A fresh large-widget entry carrying the pills above.
    private static func largeEntry(period: Double) -> GoEntry {
        var entry = GoEntry.sample
        entry.metrics = largeMetrics(period: period)
        return entry
    }

    private static let eyracSnapshot = WidgetSnapshot(
        updatedAt: updatedAt,
        spotID: "arcachon-eyrac",
        spotName: "Arcachon-Eyrac",
        activity: .shoreFishing,
        isGo: false,
        isUnavailable: false,
        answer: "Coefficient trop faible",
        lines: [
            .init(activity: .shoreFishing, isUnavailable: false, isGo: false, answer: "Coefficient trop faible"),
            .init(activity: .boating, isUnavailable: false, isGo: true, answer: "15 h 30 à 17 h 30"),
            .init(activity: .walking, isUnavailable: false, isGo: true, answer: "15 h 30 à 19 h 30"),
            .init(
                activity: .swimming,
                isUnavailable: false,
                isGo: false,
                answer: SwimmingRiskLevel.low.label,
                warning: SwimmingRiskLevel.low.widgetWarning(for: .bassin),
                swimmingLevel: .low)
        ],
        metrics: [
            .init(id: "tide", symbol: "water.waves.and.arrow.trianglehead.down", value: "3,8 m", caption: "descend"),
            .init(id: "wind", symbol: "wind", value: "7", caption: "km/h O"),
            .init(id: "swell", symbol: "water.waves", value: "Calme", caption: "estimée"),
            .init(id: "weather", symbol: "cloud.sun", value: "22°", caption: "éclaircies")
        ],
        isSampleData: true)

    private static let pointeSnapshot = WidgetSnapshot(
        updatedAt: updatedAt,
        spotID: "pointe-de-grave",
        spotName: "Pointe de Grave",
        activity: .surfing,
        isGo: true,
        isUnavailable: false,
        answer: "14 h 00 à 17 h 30",
        lines: [
            .init(activity: .shoreFishing, isUnavailable: false, isGo: false, answer: "Pluie"),
            .init(activity: .surfing, isUnavailable: false, isGo: true, answer: "14 h 00 à 17 h 30"),
            .init(activity: .boating, isUnavailable: false, isGo: true, answer: "13 h 30 à 18 h 00"),
            .init(activity: .walking, isUnavailable: false, isGo: false, answer: "Pluie"),
            .init(
                activity: .swimming,
                isUnavailable: false,
                isGo: false,
                answer: SwimmingRiskLevel.moderate.label,
                warning: SwimmingRiskLevel.moderate.widgetWarning(for: .medoc),
                swimmingLevel: .moderate)
        ],
        metrics: [
            .init(id: "tide", symbol: "water.waves.and.arrow.trianglehead.down", value: "2,1 m", caption: "descend"),
            .init(id: "wind", symbol: "wind", value: "14", caption: "km/h NO"),
            .init(id: "swell", symbol: "water.waves", value: "1,2 m", caption: "période 11 s"),
            .init(id: "weather", symbol: "cloud.rain", value: "17 °C", caption: "pluie")
        ],
        isSampleData: true)
}
