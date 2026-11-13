@testable import Estran
import EstranCore
import SwiftUI
import XCTest

/// W-DUO — renders the three main screens at the Duo's two point sizes so the
/// wide layouts can be seen and measured without the Duo simulator (its runtime
/// crashed PosterBoard and froze the machine).
///
/// The Duo exposes 2853 × 2007 px unfolded and 1398 × 2034 px folded at 3×, so
/// the renders use **951 × 669 pt** and **466 × 678 pt**. The size class is
/// injected: `ImageRenderer` has no window, and the single-column fallback for
/// an unmeasured window is the size class (`OceanLayout`).
///
/// PNGs land in the app's Documents/duo-renders; `duo-renders` is copied to
/// `build/store/duo-renders/` for the App Store material.
///
/// **Opt-in.** Rendering a whole screen needs a live simulator process, and the
/// build machine's iOS 27.2 Duo runtime sends PosterBoard into a crash loop, so
/// these tests skip unless the runner is asked for them:
///
/// ```sh
/// TEST_RUNNER_ESTRAN_DUO_RENDERS=1 xcodebuild test \
///   -destination 'id=<simulator-udid>' \
///   -only-testing:EstranTests/DuoLayoutRenderTests
/// ```
@MainActor
final class DuoLayoutRenderTests: XCTestCase {
    private static let unfolded = CGSize(width: 951, height: 669)
    private static let folded = CGSize(width: 466, height: 678)

    private var renderDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("duo-renders", isDirectory: true)
    }

    /// Skips the whole file unless the run explicitly asks for the renders.
    private func requireOptIn() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["ESTRAN_DUO_RENDERS"] == "1",
            "Set TEST_RUNNER_ESTRAN_DUO_RENDERS=1 to render the Duo layout PNGs.")
    }

    // MARK: - Home

    func testHomeRendersOnBothDuoDisplays() async throws {
        try requireOptIn()
        let app = await loadedApp()
        let unfolded = try render(
            HomeView().environment(app),
            size: Self.unfolded,
            sizeClass: .regular,
            name: "home-unfolded")
        let folded = try render(
            HomeView().environment(app),
            size: Self.folded,
            sizeClass: .compact,
            name: "home-folded")

        XCTAssertEqual(unfolded.width, Self.unfolded.width, accuracy: 1)
        XCTAssertEqual(folded.width, Self.folded.width, accuracy: 1)
        XCTAssertNotEqual(
            unfolded, folded,
            "the unfolded render must not be the phone layout stretched")
    }

    /// AX5 on the unfolded display: the reflow ladder still wins, so the screen
    /// is the single column capped at `readableContentWidth`, not a squeezed
    /// two-column split.
    func testHomeReflowsAtAX5OnTheUnfoldedDisplay() async throws {
        try requireOptIn()
        let app = await loadedApp()
        let wideAX5 = try render(
            HomeView().environment(app),
            size: Self.unfolded,
            sizeClass: .regular,
            dynamicTypeSize: .accessibility5,
            name: "home-unfolded-ax5")
        XCTAssertEqual(wideAX5.width, Self.unfolded.width, accuracy: 1)
    }

    // MARK: - Spots

    func testSpotsRendersOnBothDuoDisplays() async throws {
        try requireOptIn()
        let app = await loadedApp()
        let unfolded = try render(
            NavigationStack { SpotsView() }.environment(app),
            size: Self.unfolded,
            sizeClass: .regular,
            name: "spots-unfolded")
        let folded = try render(
            NavigationStack { SpotsView() }.environment(app),
            size: Self.folded,
            sizeClass: .compact,
            name: "spots-folded")

        XCTAssertEqual(unfolded.width, Self.unfolded.width, accuracy: 1)
        XCTAssertEqual(folded.width, Self.folded.width, accuracy: 1)
    }

    // MARK: - Spot detail

    func testSpotDetailRendersOnBothDuoDisplays() async throws {
        try requireOptIn()
        let app = await loadedApp()
        let unfolded = try render(
            NavigationStack { SpotDetailView() }.environment(app),
            size: Self.unfolded,
            sizeClass: .regular,
            name: "spot-detail-unfolded")
        let folded = try render(
            NavigationStack { SpotDetailView() }.environment(app),
            size: Self.folded,
            sizeClass: .compact,
            name: "spot-detail-folded")

        XCTAssertEqual(unfolded.width, Self.unfolded.width, accuracy: 1)
        XCTAssertEqual(folded.width, Self.folded.width, accuracy: 1)
        XCTAssertNotEqual(unfolded, folded)
    }

    // MARK: - Rendering

    /// Draws one screen at `size` and returns the rendered size in points.
    @discardableResult
    private func render(
        _ view: some View,
        size: CGSize,
        sizeClass: UserInterfaceSizeClass,
        dynamicTypeSize: DynamicTypeSize = .large,
        name: String) throws -> CGSize
    {
        let directory = renderDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let content = view
            .environment(\.horizontalSizeClass, sizeClass)
            .environment(\.dynamicTypeSize, dynamicTypeSize)
            .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(size)

        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw RenderError.couldNotRender(name)
        }
        try data.write(to: directory.appendingPathComponent("\(name).png"))
        XCTAssertGreaterThan(data.count, 4096, "\(name) rendered blank")
        return image.size
    }

    private enum RenderError: Error {
        case couldNotRender(String)
    }

    // MARK: - Fixture

    /// The real composition root on the DEBUG demo provider: the embedded tide
    /// model and the real decision engine, so the render shows what the app
    /// shows — not a mockup of it.
    private func loadedApp() async -> AppModel {
        let app = AppModel()
        await app.reload()
        app.select(activity: .shoreFishing)
        return app
    }
}
