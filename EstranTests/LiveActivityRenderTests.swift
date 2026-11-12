import EstranCore
import SwiftUI
import WidgetKit
import XCTest

/// W-LACAUTION — renders the Live Activity card to PNG at the two lock-screen
/// widths (370 and 393 pt) so the caution row can be seen and its height
/// measured without an ActivityKit context or a device.
///
/// The card is drawn from the same `LiveActivityCard` view the widget extension
/// compiles, fed exactly what `GoLiveActivityView` feeds it, so the measurement
/// is the real layout — not a mockup. The system caps the lock-screen card at
/// roughly 160 pt; the go+caution states must stay under it.
final class LiveActivityRenderTests: XCTestCase {
    /// `true` while the render target exists, so the PNGs land somewhere the
    /// integrator can copy out of the app container.
    private var renderDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("lacaution", isDirectory: true)
    }

    /// The system's practical limit for the lock-screen banner, in points.
    private static let lockScreenLimit: CGFloat = 160

    @MainActor
    func testRenderTheCautionCardAtBothLockScreenWidths() throws {
        let directory = renderDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for width in [CGFloat(370), CGFloat(393)] {
            let night = try render(
                Self.nightFishingCard,
                width: width,
                to: directory.appendingPathComponent("lacaution-\(Int(width))-go-nuit.png"))
            let passes = try render(
                Self.passesCard,
                width: width,
                to: directory.appendingPathComponent("lacaution-\(Int(width))-go-passes.png"))
            let swimming = try render(
                Self.swimmingCard,
                width: width,
                to: directory.appendingPathComponent("lacaution-\(Int(width))-baignade.png"))

            print(
                "LACAUTION width=\(Int(width)) "
                    + "night=\(night) passes=\(passes) swimming=\(swimming)")

            XCTAssertLessThanOrEqual(
                night, Self.lockScreenLimit,
                "the night caution must keep the card within ~160 pt at \(Int(width)) pt")
            XCTAssertLessThanOrEqual(
                passes, Self.lockScreenLimit,
                "the longest caution (Bassin passes) must keep the card within ~160 pt")
            XCTAssertLessThanOrEqual(
                swimming, Self.lockScreenLimit,
                "swimming was already within the limit and is unchanged")
        }

        print("LACAUTION_RENDER_DIR=\(directory.path)")
    }

    /// AX5: the caution wraps instead of truncating, so the card grows rather
    /// than clipping its first words. The render is the visual proof; the height
    /// must exceed the default-size one because the sentence takes more lines.
    @MainActor
    func testTheCautionWrapsAtAX5() throws {
        let directory = renderDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let defaultHeight = try render(
            Self.passesCard,
            width: 370,
            to: directory.appendingPathComponent("lacaution-370-go-passes.png"))
        let ax5Height = try render(
            Self.passesCard,
            width: 370,
            dynamicTypeSize: .accessibility5,
            to: directory.appendingPathComponent("lacaution-370-go-passes-ax5.png"))

        print("LACAUTION ax5=\(ax5Height) default=\(defaultHeight)")
        XCTAssertGreaterThan(
            ax5Height, defaultHeight,
            "AX5 grows and wraps the caution; it never truncates it")
    }

    // MARK: - Rendering

    /// Renders one card at `width` and returns the rendered height in points.
    @MainActor
    private func render(
        _ card: LiveActivityCard,
        width: CGFloat,
        dynamicTypeSize: DynamicTypeSize = .large,
        to url: URL) throws -> CGFloat
    {
        let view = card
            .environment(\.dynamicTypeSize, dynamicTypeSize)
            .environment(\.widgetRenderingMode, .fullColor)
            .frame(width: width)
            .background { OceanPalette.backgroundGradient }

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)

        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw RenderError.couldNotRender
        }
        try data.write(to: url)
        return image.size.height
    }

    private enum RenderError: Error {
        case couldNotRender
    }

    // MARK: - Fixtures

    private static let now = Date(timeIntervalSince1970: 1_793_000_000)
    private static let spot = SpotCatalog.pointeDeGrave

    private static func card(
        activity: Activity,
        isGo: Bool = true,
        isUnavailable: Bool = false,
        swimmingAdvisory: SwimmingAdvisory? = nil,
        caution: String? = nil) -> LiveActivityCard
    {
        LiveActivityCard(
            activityName: activity.displayName,
            spotName: spot.name,
            timeZone: spot.timezone,
            isSwimmingFlag: activity == .swimming,
            isUnavailable: isUnavailable,
            isGo: isGo,
            nextWindowStart: now.addingTimeInterval(1500),
            swimmingAdvisory: swimmingAdvisory,
            caution: caution)
    }

    private static let nightFishingCard = card(
        activity: .shoreFishing,
        caution: ActivityCaution.nightFishing)

    private static let passesCard = card(
        activity: .boating,
        caution: ActivityCaution.boatingPasses)

    private static let swimmingCard = card(
        activity: .swimming,
        isGo: false,
        swimmingAdvisory: SwimmingAdvisory(
            level: .strong,
            region: .medoc,
            conditionsLine: "Vent 38 km/h · houle 1,5 m · eau 17 °C",
            notes: ["vent fort", "houle trop forte"]))
}
