import EstranCore
import SwiftUI
import UIKit
import WidgetKit
import XCTest

/// W-LOCK — the Lock Screen families must never render an empty slot.
///
/// The owner's build 5 showed nothing in `accessoryRectangular`,
/// `accessoryCircular` and `accessoryInline` on a real iPhone, with the Home
/// Screen widgets working. The views themselves were the suspect: 11 pt captions
/// at 75 % opacity, accent applied to everything, and the circular background
/// drawn *inside* the content. This test renders each family in the two Lock
/// Screen rendering modes and **fails when the slot is blank**, so "it shows
/// nothing" becomes a red test instead of a TestFlight finding.
///
/// It also writes the shots to the app's Documents directory
/// (`lock-<family>-<state>-<mode>.png`) so the states can be looked at without
/// adding widgets to a Lock Screen.
final class AccessoryWidgetRenderTests: XCTestCase {
    /// Real slot sizes on a 6.3″ iPhone at the default text size. The exact
    /// point size varies by device; what matters here is that the content has a
    /// plausible box to draw in.
    private enum Family: String, CaseIterable {
        case rectangular
        case circular
        case inline

        var size: CGSize {
            switch self {
            case .rectangular: CGSize(width: 176, height: 76)
            case .circular: CGSize(width: 88, height: 88)
            case .inline: CGSize(width: 280, height: 26)
            }
        }

        /// Smallest share of lit pixels a slot that shows words can have. A blank
        /// render scores 0; the measured minimums are ~3 % (rectangular
        /// placeholder), ~3 % (circular unavailable) and ~2 % (inline), so the
        /// floor sits just below them and still catches an empty slot.
        var minimumContentShare: Double {
            switch self {
            case .rectangular: 0.025
            case .circular: 0.02
            case .inline: 0.015
            }
        }
    }

    private enum State: String, CaseIterable {
        case go
        case noGo = "nogo"
        case swimming
        case unavailable
        case placeholder

        var entry: GoEntry {
            switch self {
            case .go: .sample
            case .noGo: .sampleNoGo
            case .swimming: .sampleSwimming
            case .unavailable: Self.unavailableEntry
            case .placeholder: .placeholder
            }
        }

        private static let unavailableEntry = GoEntry(
            date: Date(),
            title: "Arcachon-Eyrac",
            answer: "Données indisponibles",
            detail: "Données indisponibles",
            isGo: false,
            isUnavailable: true,
            lines: [
                .init(
                    activity: .shoreFishing,
                    isUnavailable: true,
                    isGo: false,
                    answer: "Données indisponibles")
            ],
            metrics: [],
            selectedActivity: .shoreFishing)
    }

    /// Rendering modes to prove: the Lock Screen uses `.vibrant`, the tinted
    /// Home Screen uses `.accented`, and `.fullColor` is the reference.
    private static var modes: [(name: String, mode: WidgetRenderingMode)] {
        [
            ("vibrant", .vibrant),
            ("accented", .accented),
            ("full", .fullColor)
        ]
    }

    private var renderDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("lock", isDirectory: true)
    }

    // MARK: - The families are declared

    /// A family missing from `supportedFamilies` is not a blank slot: it is no
    /// slot at all. Cheap and decisive.
    func testAccessoryFamiliesAreSupported() {
        XCTAssertTrue(GoWidget.families.contains(.accessoryRectangular))
        XCTAssertTrue(GoWidget.families.contains(.accessoryCircular))
        XCTAssertTrue(GoWidget.families.contains(.accessoryInline))
        XCTAssertEqual(GoWidget.accessoryFamilies.count, 3)
    }

    // MARK: - No state renders an empty slot

    @MainActor
    func testEveryAccessoryFamilyDrawsEveryState() throws {
        // Start clean: a shot from an earlier run must not make today's render
        // fail on an existing file.
        try? FileManager.default.removeItem(at: renderDirectory)
        try FileManager.default.createDirectory(
            at: renderDirectory, withIntermediateDirectories: true)

        for family in Family.allCases {
            for state in State.allCases {
                for mode in Self.modes {
                    let content = Self.view(family, entry: state.entry)
                        .environment(\.widgetRenderingMode, mode.mode)
                        .environment(\.colorScheme, .dark)
                        .environment(\.dynamicTypeSize, .large)
                        .environment(\.levelOfDetail, .default)
                        .frame(width: family.size.width, height: family.size.height)

                    // The measurement render sits on black: an empty slot must
                    // score zero, and the wallpaper must not count as content.
                    let image = try XCTUnwrap(
                        Self.render(content.background(Color.black), opaque: true),
                        "\(family.rawValue)/\(state.rawValue)/\(mode.name) did not render")
                    let share = try XCTUnwrap(Self.litShare(image))
                    XCTAssertGreaterThan(
                        share,
                        family.minimumContentShare,
                        "\(family.rawValue) \(state.rawValue) \(mode.name) is blank: "
                            + "\(Int(share * 1000))‰ of the slot is lit")

                    // The shot a human looks at: same pixels, over a wallpaper.
                    if let shot = Self.render(
                        content.padding(12).background { LockScreenWallpaper() },
                        opaque: true)
                    {
                        let name = "lock-\(family.rawValue)-\(state.rawValue)-\(mode.name).png"
                        try shot.pngData()?.write(
                            to: renderDirectory.appendingPathComponent(name),
                            options: .atomic)
                    }
                }
            }
        }
        print("LOCK_RENDER_DIR=\(renderDirectory.path)")
    }

    /// The vibrant mode is the one the Lock Screen actually uses: it desaturates
    /// everything and dims `.secondary`. The answer must still be the brightest
    /// thing in the slot, or the eye finds the wallpaper instead.
    @MainActor
    func testVibrantTextOutweighsSecondaryText() throws {
        for family in Family.allCases {
            for state in State.allCases {
                let content = Self.view(family, entry: state.entry)
                    .environment(\.widgetRenderingMode, .vibrant)
                    .environment(\.colorScheme, .dark)
                    .environment(\.dynamicTypeSize, .large)
                    .frame(width: family.size.width, height: family.size.height)
                let image = try XCTUnwrap(
                    Self.render(content.background(Color.black), opaque: true))
                let brightest = try XCTUnwrap(Self.brightestShare(image))
                XCTAssertGreaterThan(
                    brightest,
                    family.minimumContentShare / 2,
                    "\(family.rawValue) \(state.rawValue) has no bright element")
            }
        }
    }

    // MARK: - Rendering

    @ViewBuilder
    private static func view(_ family: Family, entry: GoEntry) -> some View {
        switch family {
        case .rectangular: GoAccessoryRectangularView(entry: entry)
        case .circular: GoAccessoryCircularView(entry: entry)
        case .inline: GoAccessoryInlineView(entry: entry)
        }
    }

    @MainActor
    private static func render(_ content: some View, opaque: Bool) -> UIImage? {
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        renderer.isOpaque = opaque
        return renderer.uiImage
    }

    /// Share of pixels brighter than 40 % luminance — words and glyphs, not the
    /// black canvas.
    private static func litShare(_ image: UIImage) -> Double? {
        share(image, threshold: 0.4)
    }

    /// Share of pixels brighter than 70 % luminance — the answer, not the dimmed
    /// detail line.
    private static func brightestShare(_ image: UIImage) -> Double? {
        share(image, threshold: 0.7)
    }

    private static func share(_ image: UIImage, threshold: Double) -> Double? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            return nil
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        var lit = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[index + 3]) / 255
            let luminance = (0.2126 * Double(pixels[index])
                + 0.7152 * Double(pixels[index + 1])
                + 0.0722 * Double(pixels[index + 2])) / 255
            if luminance * alpha > threshold {
                lit += 1
            }
        }
        return Double(lit) / Double(width * height)
    }
}

/// A lock-screen-ish wallpaper: the slot needs something behind it to be
/// looked at the way the owner sees it.
struct LockScreenWallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.20, blue: 0.31),
                    Color(red: 0.01, green: 0.08, blue: 0.15),
                    .black
                ],
                startPoint: .top,
                endPoint: .bottom)
            RadialGradient(
                colors: [Color(red: 0.19, green: 0.84, blue: 0.78).opacity(0.18), .clear],
                center: UnitPoint(x: 0.8, y: 0.15),
                startRadius: 8,
                endRadius: 320)
        }
    }
}
