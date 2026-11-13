@testable import Estran
import SwiftUI
import XCTest

/// W-DUO — the two-column decision is geometry, not device.
///
/// The unfolded Duo is ~951 × 669 pt and the folded one ~466 × 678 pt; neither
/// is a device the test machine can boot (its runtime crashed PosterBoard). What
/// the tests can pin is the rule that separates them, which is the part that
/// must not regress.
@MainActor
final class OceanLayoutTests: XCTestCase {
    private func wide(
        _ width: CGFloat,
        _ sizeClass: UserInterfaceSizeClass?,
        _ typeSize: DynamicTypeSize = .large) -> Bool
    {
        OceanLayout.usesTwoColumns(
            width: width,
            sizeClass: sizeClass,
            dynamicTypeSize: typeSize)
    }

    // MARK: - The two Duo displays

    func testUnfoldedDuoIsTwoColumns() {
        XCTAssertTrue(wide(951, .regular))
    }

    func testFoldedDuoIsThePhoneLayout() {
        XCTAssertFalse(
            wide(466, .compact),
            "the cover display is the phone layout the design was drawn for")
    }

    func testClassicPhonesStaySingleColumn() {
        XCTAssertFalse(wide(440, .compact), "iPhone 18 Pro Max portrait")
        XCTAssertFalse(wide(402, .compact), "the Figma frame")
        XCTAssertFalse(wide(375, .compact), "iPhone SE")
    }

    func testLandscapeIPhoneGetsTheWideLayout() {
        XCTAssertTrue(wide(956, .regular), "iPhone 18 Pro Max landscape")
    }

    // MARK: - The rule

    func testBreakpointIsInclusive() {
        XCTAssertTrue(wide(OceanLayout.wideBreakpoint, .regular))
        XCTAssertFalse(wide(OceanLayout.wideBreakpoint - 1, .regular))
    }

    /// Before the first layout pass the view has no measured width. The size
    /// class is then the only signal — and an unmeasured compact window must
    /// not jump into two columns.
    func testSizeClassIsTheFallbackWhenNoWidthIsKnown() {
        XCTAssertTrue(wide(0, .regular))
        XCTAssertFalse(wide(0, .compact))
        XCTAssertFalse(wide(0, nil))
    }

    // MARK: - Dynamic Type wins

    func testAccessibilitySizesNeverUseTwoColumns() {
        for typeSize in [DynamicTypeSize.accessibility1, .accessibility3, .accessibility5] {
            XCTAssertFalse(
                wide(951, .regular, typeSize),
                "the reflow ladder stacks pairs at AX sizes (\(typeSize))")
        }
    }

    func testStandardSizesStillGetTwoColumns() {
        for typeSize in [DynamicTypeSize.large, .xLarge, .xxxLarge] {
            XCTAssertTrue(wide(951, .regular, typeSize), "\(typeSize) is not an AX size")
        }
    }

    // MARK: - The readable measure

    func testReadableWidthIsNarrowerThanTheUnfoldedDisplay() {
        XCTAssertLessThan(OceanLayout.readableContentWidth, 951)
        XCTAssertGreaterThan(
            OceanLayout.readableContentWidth,
            OceanLayout.wideBreakpoint,
            "two columns must fit inside the cap")
    }

    func testSideColumnLeavesRoomForTheLeadingColumn() {
        let leading = OceanLayout.readableContentWidth
            - OceanLayout.sideColumnIdealWidth
            - OceanLayout.columnSpacing
        XCTAssertGreaterThanOrEqual(
            leading, 380,
            "the answer card and the five activity chips need a real column")
        XCTAssertLessThanOrEqual(
            OceanLayout.sideColumnMaximumWidth, OceanLayout.readableContentWidth / 2)
    }
}
