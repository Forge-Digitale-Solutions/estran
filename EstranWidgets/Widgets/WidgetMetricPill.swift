import EstranCore
import SwiftUI
import WidgetKit

/// One conditions pill (« Marée », « Vent », « Houle », « Météo ») and the large
/// widget's row of four.
///
/// **Why the caption is chosen instead of wrapped.** The owner's real-device
/// capture of the large widget (2026-11-13, `W-PILL`) shows the HOULE pill
/// taller than the other three: « période 5 s » wrapped onto two lines inside a
/// ~74 pt pill, so the row read as a broken grid. The caption is measured with
/// `ViewThatFits` — the full words the app's `ConditionsGrid` shows when they
/// fit, the snapshot's compact form otherwise (« pér. 5 s ») — and is never
/// ellipsised: the last candidate shrinks before it truncates.
struct WidgetMetricPill: View {
    let metric: WidgetSnapshot.Metric
    /// The value's style: the large widget's row is tighter than the medium
    /// card's 2 × 2 grid.
    var valueFont: Font = OceanTypography.tabLabel
    /// `false` when `levelOfDetail == .simplified`: the app drops the detail
    /// line too instead of showing a guessed one.
    var showsCaption = true
    /// The medium card tints its value in accented rendering modes; the large
    /// row leaves it plain white.
    var accentedValue = false
    /// `true` inside the fixed-height `WidgetMetricsRow`: the glass tile then
    /// fills the row's height instead of hugging its own text.
    var fillsRow = false

    /// One line of spacing between the three lines, as the app's tile row.
    private let contentSpacing: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            titleRow

            Text(metric.value)
                .font(valueFont)
                .foregroundStyle(OceanPalette.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .widgetAccentable(accentedValue)

            if showsCaption {
                caption
            }
        }
        .padding(.horizontal, OceanSpacing.xs)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: fillsRow ? .infinity : nil, alignment: .topLeading)
        .widgetGlassTile(cornerRadius: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private var titleRow: some View {
        HStack(spacing: 3) {
            Image(systemName: metric.symbol)
                .widgetAccentedRenderingMode(.accentedDesaturated)
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.sand)
                .widgetAccentable()
                .accessibilityHidden(true)

            if !metric.title.isEmpty {
                Text(metric.title)
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.sand)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    /// The detail line, on one line, in the fullest form the pill can hold.
    private var caption: some View {
        ViewThatFits(in: .horizontal) {
            // Measured at its own width: a `Text` that is allowed to wrap or
            // shear always « fits », and the pill would wrap again. The guard
            // demands half of the tile's trailing padding as breathing room: a
            // caption that only fits by eating its whole padding reads as
            // overflowing, which is what the owner saw.
            Text(metric.caption)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.trailing, OceanSpacing.xxs)

            Text(metric.compactCaption ?? metric.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)
        }
        .font(OceanTypography.smallLabel)
        .foregroundStyle(OceanPalette.white.opacity(0.75))
        .fixedSize(horizontal: false, vertical: true)
    }

    /// What VoiceOver reads: the full wording, never the shortened form the
    /// pill had to draw (« période 11 s », as the app says it).
    private var spoken: String {
        let detail = metric.caption.isEmpty
            ? metric.value
            : "\(metric.value), \(metric.caption)"
        return metric.title.isEmpty ? detail : "\(metric.title) : \(detail)"
    }
}

/// The large widget's four conditions pills, in one row of one height.
struct WidgetMetricsRow: View {
    let metrics: [WidgetSnapshot.Metric]

    /// One height for every pill, scaled with the caption text.
    ///
    /// An `HStack` sizes each child to its own ideal height, so the pill whose
    /// caption wrapped stayed taller than its neighbours. The row is fixed
    /// instead, and every pill fills it: 58 pt is three caption2 lines plus the
    /// 6 pt vertical padding at the default size, and `@ScaledMetric` keeps that
    /// true when Dynamic Type grows the text.
    @ScaledMetric(relativeTo: .caption2) private var height: CGFloat = 58

    var body: some View {
        HStack(alignment: .top, spacing: OceanSpacing.xxs) {
            ForEach(metrics) { metric in
                WidgetMetricPill(metric: metric, fillsRow: true)
            }
        }
        .frame(height: height)
    }
}
