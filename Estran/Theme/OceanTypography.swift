import SwiftUI

/// Typography scale for the iOS 27 Liquid Glass design.
///
/// **Every style is expressed as a semantic `Font.TextStyle`**, never as a bare
/// `Font.system(size:)`: a fixed point size does not follow Dynamic Type, and
/// AX5 is a release gate from M3 (`DESIGN_REFERENCE.md` §2.1). The two giant
/// verdict sizes keep a numeric base because they are display-only, but they are
/// scaled per view with `@ScaledMetric` (`goBadgeBaseSize`).
enum OceanTypography {
    /// 34 pt at the default size, bold.
    static let largeTitle = Font.system(.largeTitle, design: .default).weight(.bold)
    /// 22 pt at the default size, semibold.
    static let metricValue = Font.system(.title2, design: .default).weight(.semibold)
    /// 17 pt at the default size, semibold.
    static let bodyEmphasized = Font.system(.body, design: .default).weight(.semibold)
    /// 17 pt at the default size.
    static let body = Font.system(.body, design: .default)
    /// 15 pt at the default size.
    static let subtitle = Font.system(.subheadline, design: .default)
    /// 13 pt at the default size, semibold.
    static let button = Font.system(.footnote, design: .default).weight(.semibold)
    /// 13 pt at the default size, medium.
    static let caption = Font.system(.footnote, design: .default).weight(.medium)
    /// 11 pt at the default size.
    static let smallLabel = Font.system(.caption2, design: .default)
    /// 11 pt at the default size, semibold — tab bar and widget labels.
    static let tabLabel = Font.system(.caption2, design: .default).weight(.semibold)

    /// Base size of the giant Oui/Non verdict. Views scale it with
    /// `@ScaledMetric(relativeTo: .largeTitle)`; it is never used raw.
    static let goBadgeBaseSize: CGFloat = 76
    /// Base size of the widget verdict, scaled the same way inside widgets.
    static let widgetGoBadgeBaseSize: CGFloat = 48

    /// Rounded display font at an already-scaled size.
    static func rounded(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}
