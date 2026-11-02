@testable import Estran
import SwiftUI
import XCTest

/// The accessibility decision behind the glass surfaces (`worksplit.md` §6 M3:
/// Reduce Transparency, Increase Contrast and Reduce Motion are release gates).
///
/// `glassEffect` renders nothing a test can read, so the tests pin the decision
/// that feeds it: which of the four looks a surface takes, and the exact border
/// and backing it draws.
@MainActor
final class AccessibilityStatesTests: XCTestCase {
    // MARK: - The four combinations

    func testDefaultSurfaceIsGlassWithoutBorderOrBacking() {
        let appearance = GlassAppearance(reduceTransparency: false, increaseContrast: false)

        XCTAssertFalse(appearance.usesSolidFill)
        XCTAssertEqual(appearance.borderWidth, 0)
        XCTAssertEqual(appearance.borderOpacity, 0)
        XCTAssertEqual(appearance.backingOpacity, 0)
        XCTAssertFalse(appearance.drawsBorder)
    }

    func testReduceTransparencyReplacesGlassWithAnOpaqueCard() {
        let appearance = GlassAppearance(reduceTransparency: true, increaseContrast: false)

        XCTAssertTrue(appearance.usesSolidFill)
        XCTAssertEqual(appearance.borderWidth, 1)
        XCTAssertEqual(appearance.borderOpacity, 0.18)
        XCTAssertEqual(appearance.backingOpacity, 0, "an opaque card has nothing left to darken")
        XCTAssertTrue(appearance.drawsBorder)
    }

    func testIncreaseContrastKeepsGlassAndAddsAStrongerBorder() {
        let appearance = GlassAppearance(reduceTransparency: false, increaseContrast: true)

        XCTAssertFalse(appearance.usesSolidFill)
        XCTAssertEqual(appearance.borderWidth, 1.5)
        XCTAssertEqual(appearance.borderOpacity, 0.5)
        XCTAssertEqual(appearance.backingOpacity, 0.45, "the navy backing lifts the text tokens")
        XCTAssertTrue(appearance.drawsBorder)
    }

    func testBothFlagsKeepTheOpaqueFillAndTheStrongerBorder() {
        let appearance = GlassAppearance(reduceTransparency: true, increaseContrast: true)

        XCTAssertTrue(appearance.usesSolidFill, "Reduce Transparency wins over glass")
        XCTAssertEqual(appearance.borderWidth, 1.5, "Increase Contrast is additive, never dropped")
        XCTAssertEqual(appearance.borderOpacity, 0.5)
        XCTAssertEqual(appearance.backingOpacity, 0, "the fill is already opaque")
    }

    // MARK: - Invariants across the four looks

    func testEveryLookIsDistinct() {
        let looks = [
            GlassAppearance(reduceTransparency: false, increaseContrast: false),
            GlassAppearance(reduceTransparency: true, increaseContrast: false),
            GlassAppearance(reduceTransparency: false, increaseContrast: true),
            GlassAppearance(reduceTransparency: true, increaseContrast: true)
        ]

        XCTAssertEqual(Set(looks.map(\.borderWidth)).count, 3, "0, 1 and 1.5 pt")
        XCTAssertEqual(looks.filter(\.usesSolidFill).count, 2)
        XCTAssertEqual(looks.filter(\.drawsBorder).count, 3, "only the default look is borderless")
    }

    func testBorderOpacityIsZeroExactlyWhenNoBorderIsDrawn() {
        for reduceTransparency in [false, true] {
            for increaseContrast in [false, true] {
                let appearance = GlassAppearance(
                    reduceTransparency: reduceTransparency,
                    increaseContrast: increaseContrast)

                XCTAssertEqual(
                    appearance.borderOpacity > 0,
                    appearance.drawsBorder,
                    "a border with no opacity would be an invisible stroke")
            }
        }
    }

    func testBackingIsNeverDrawnUnderAnOpaqueFill() {
        for increaseContrast in [false, true] {
            let appearance = GlassAppearance(
                reduceTransparency: true,
                increaseContrast: increaseContrast)

            XCTAssertEqual(appearance.backingOpacity, 0)
        }
    }

    // MARK: - Reduce Motion

    func testReduceMotionDropsTheAnimation() {
        XCTAssertNil(OceanGlass.animation(.spring(response: 0.45), reduceMotion: true))
        XCTAssertNil(OceanGlass.animation(nil, reduceMotion: true))
    }

    func testAnimationIsPassedThroughWhenMotionIsAllowed() {
        let spring = Animation.spring(response: 0.45)

        XCTAssertEqual(OceanGlass.animation(spring, reduceMotion: false), spring)
        XCTAssertNil(OceanGlass.animation(nil, reduceMotion: false))
    }

    // MARK: - Source compatibility

    func testSurfaceAPIKeepsWorkingWithoutArguments() {
        // Compile-time guard: the call sites in the app never pass a flag, so
        // the behaviour has to come from the environment inside the modifier.
        _ = Color.clear.oceanGlassCard()
        _ = Color.clear.oceanGlassCapsule()
        _ = Color.clear.oceanGlassCard(cornerRadius: OceanGlass.answerCornerRadius)
    }
}
