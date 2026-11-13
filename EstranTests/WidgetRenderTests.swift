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

        print("WCONF_RENDER_DIR=\(directory.path)")
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
