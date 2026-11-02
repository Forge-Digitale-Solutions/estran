import Charts
import EstranCore
import Foundation
import SwiftUI

/// Frame 02 — the tide chart card (Swift Charts).
///
/// The caller has already computed every value: this view never calls an engine
/// and never invents one (an empty `curve` renders « Données indisponibles »,
/// never a flat line at 0). The x axis is the local day, 0 h → 24 h in
/// `timeZone`, plotted as hours since local midnight so the five labels are
/// exact. Good windows are shaded, the next event is ringed and named in the
/// header. The whole card is one accessibility element labelled with
/// `accessibilitySentence`; the chart is never read shape by shape. At AX sizes
/// the chart grows, five hour labels reflow to three, and nothing clips
/// (`DESIGN_REFERENCE.md` §2.1).
struct TideChartCard: View {
    /// 10-minute samples over the local day, from `TideState.curve`.
    let curve: [TidePoint]
    /// Extrema to mark, from `TideState.allEvents`.
    let events: [TideEvent]
    /// Good windows to shade, from the decision engine.
    let goodWindows: [DateInterval]
    /// « Basse 14 h 12 · 1,2 m », or `nil` when no event is known.
    let nextEventLine: String?
    /// « Bon créneau 13 h 10 à 15 h 40 », or `nil`.
    let windowLine: String?
    let timeZone: TimeZone
    /// The current instant, drawn as a vertical rule.
    let now: Date
    /// Spoken sentence for the card, built by the caller so it matches the
    /// visible lines exactly.
    let accessibilitySentence: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 132
    @ScaledMetric(relativeTo: .body) private var markerSize: CGFloat = 9

    var body: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xs) {
            header
            if let windowLine {
                Text(windowLine)
                    .font(OceanTypography.caption)
                    .foregroundStyle(OceanPalette.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if curve.isEmpty {
                unavailable
            } else {
                chart
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(OceanSpacing.md)
        .oceanGlassCard(cornerRadius: OceanGlass.cardCornerRadius)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySentence)
    }

    // MARK: - Header

    /// « Marée » and the next event on one line, stacked when the two no longer
    /// fit side by side (Dynamic Type reflow, not truncation).
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: OceanSpacing.sm) {
                title
                Spacer(minLength: 0)
                eventLine(textAlignment: .trailing)
            }
            VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
                title
                eventLine(textAlignment: .leading)
            }
        }
    }

    private var title: some View {
        Text("Marée")
            .font(OceanTypography.bodyEmphasized)
            .foregroundStyle(OceanPalette.white)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func eventLine(textAlignment: TextAlignment) -> some View {
        if let nextEventLine {
            Text(nextEventLine)
                .font(OceanTypography.subtitle.weight(.semibold))
                .foregroundStyle(OceanPalette.turquoiseOnGlass)
                .multilineTextAlignment(textAlignment)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Unavailable

    /// No curve, no axes, no invented sample: the card states the missing data
    /// in sand and keeps whatever header lines the caller could still provide.
    private var unavailable: some View {
        Text("Données indisponibles")
            .font(OceanTypography.body)
            .foregroundStyle(OceanPalette.unavailable)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, OceanSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            windowBands
            curveMarks
            nowMarks
            eventMarks
        }
        .chartXScale(domain: 0 ... 24)
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartOverlay { proxy in
            TideChartLabels(
                axisHours: axisHours,
                event: nextEvent,
                markerSize: markerSize,
                dayStart: dayStart,
                proxy: proxy)
        }
        .frame(height: chartHeight)
        .accessibilityHidden(true)
    }

    /// Every good window, shaded from the top to the bottom of the plot area.
    @ChartContentBuilder
    private var windowBands: some ChartContent {
        ForEach(goodWindows.indices, id: \.self) { index in
            let window = goodWindows[index]
            RectangleMark(
                xStart: .value("Début du créneau", hours(window.start)),
                xEnd: .value("Fin du créneau", hours(window.end)))
                .foregroundStyle(OceanPalette.chartHighlight.opacity(0.18))
        }
    }

    /// The tide itself: a turquoise line over a turquoise area that fades to
    /// nothing at the bottom.
    @ChartContentBuilder
    private var curveMarks: some ChartContent {
        ForEach(curve.indices, id: \.self) { index in
            let point = curve[index]
            AreaMark(
                x: .value("Heure", hours(point.time)),
                y: .value("Hauteur", point.height))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(areaFill)
            LineMark(
                x: .value("Heure", hours(point.time)),
                y: .value("Hauteur", point.height))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .foregroundStyle(OceanPalette.turquoise)
        }
    }

    /// The dashed rule at `now` and the dot where it meets the curve. Nothing is
    /// drawn when `now` falls outside the day or outside the samples.
    @ChartContentBuilder
    private var nowMarks: some ChartContent {
        if let point = nowPoint {
            RuleMark(x: .value("Maintenant", hours(now)))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(OceanPalette.white.opacity(0.7))
            PointMark(
                x: .value("Maintenant", hours(now)),
                y: .value("Hauteur", point.height))
                .symbol { nowDot }
        }
    }

    /// The next extremum: a ring on the curve. Its height is drawn by
    /// `TideChartLabels`, not by a mark annotation: the two point marks share one
    /// Charts series, so an annotation anchors between them, not on the event.
    @ChartContentBuilder
    private var eventMarks: some ChartContent {
        if let event = nextEvent {
            PointMark(
                x: .value("Prochaine marée", hours(event.time)),
                y: .value("Hauteur", event.height))
                .symbol { eventDot }
        }
    }

    private var nowDot: some View {
        Circle()
            .fill(OceanPalette.turquoise)
            .overlay {
                Circle().strokeBorder(OceanPalette.white, lineWidth: 2)
            }
            .frame(width: markerSize, height: markerSize)
    }

    private var eventDot: some View {
        Circle()
            .strokeBorder(OceanPalette.white, lineWidth: 1.5)
            .frame(width: markerSize * 0.8, height: markerSize * 0.8)
    }

    private var areaFill: LinearGradient {
        LinearGradient(
            colors: [
                OceanPalette.turquoise.opacity(0.35),
                OceanPalette.turquoise.opacity(0.02)
            ],
            startPoint: .top,
            endPoint: .bottom)
    }

    // MARK: - Axis and geometry

    /// 0, 6, 12, 18, 24 h at the default size; 0, 12, 24 h from the accessibility
    /// sizes, where five labels would collide on a phone width.
    private var axisHours: [Double] {
        dynamicTypeSize.isAccessibilitySize ? [0, 12, 24] : [0, 6, 12, 18, 24]
    }

    private var calendar: Calendar {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        return gregorian
    }

    private var dayStart: Date {
        calendar.startOfDay(for: now)
    }

    /// Hours since local midnight — the chart's x axis.
    private func hours(_ date: Date) -> Double {
        date.timeIntervalSince(dayStart) / 3600
    }

    /// The measured heights, with headroom for the line and for the height label
    /// above a high tide. Never a zero line: the bottom is the lowest sample.
    private var yDomain: ClosedRange<Double> {
        let heights = curve.map(\.height)
        // Unreachable: the chart is only built when `curve` is not empty.
        guard let low = heights.min(), let high = heights.max() else { return 0 ... 1 }
        let span = max(high - low, 0.4)
        return (low - span * 0.2) ... (high + span * 0.35)
    }

    /// The curve interpolated at `now`. `nil` outside the day or outside the
    /// samples: the dot is not drawn rather than placed on an invented height.
    private var nowPoint: TidePoint? {
        guard hours(now) >= 0, hours(now) <= 24,
              let first = curve.first, let last = curve.last,
              now >= first.time, now <= last.time
        else {
            return nil
        }
        if let exact = curve.first(where: { $0.time == now }) {
            return exact
        }
        guard let upperIndex = curve.firstIndex(where: { $0.time > now }), upperIndex > 0 else {
            return nil
        }
        let lower = curve[upperIndex - 1]
        let upper = curve[upperIndex]
        let span = upper.time.timeIntervalSince(lower.time)
        guard span > 0 else { return nil }
        let fraction = now.timeIntervalSince(lower.time) / span
        return TidePoint(
            time: now,
            height: lower.height + (upper.height - lower.height) * fraction)
    }

    /// The first extremum in the day that is still to come and on the axis.
    private var nextEvent: TideEvent? {
        events
            .filter { $0.time >= now && hours($0.time) <= 24 }
            .min { $0.time < $1.time }
    }
}

/// The hour scale and the next event's height, drawn over the plot area.
///
/// Positioned from `ChartProxy` instead of `chartXAxis`: the built-in axis drops
/// the trailing « 24 h » label as soon as it cannot fit half a label past the
/// plot edge, and that mark is the end of the local day. Here the ends are
/// pinned to the edges and the middle marks sit at their exact hour.
private struct TideChartLabels: View {
    let axisHours: [Double]
    let event: TideEvent?
    let markerSize: CGFloat
    let dayStart: Date
    let proxy: ChartProxy

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                scale(width: geometry.size.width, height: geometry.size.height)
                eventHeight
            }
        }
    }

    private func scale(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            label(axisHours.first ?? 0)
                .frame(width: width, height: height, alignment: .bottomLeading)
            label(axisHours.last ?? 24)
                .frame(width: width, height: height, alignment: .bottomTrailing)
            ForEach(Array(axisHours.dropFirst().dropLast()), id: \.self) { hour in
                Color.clear
                    .frame(width: 0, height: 0)
                    .overlay(alignment: .bottom) { label(hour) }
                    .position(x: width * hour / 24, y: height)
            }
        }
    }

    private func label(_ hour: Double) -> some View {
        Text("\(Int(hour)) h")
            .font(OceanTypography.caption)
            .foregroundStyle(OceanPalette.white.opacity(0.6))
            .fixedSize()
            .padding(.bottom, OceanSpacing.xxs)
    }

    /// The next event's height, bottom-anchored above its ring so it grows upward.
    @ViewBuilder
    private var eventHeight: some View {
        if let event,
           let anchorX = proxy.position(forX: hours(event.time)),
           let anchorY = proxy.position(forY: event.height)
        {
            Color.clear
                .frame(width: 0, height: 0)
                .overlay(alignment: .bottom) {
                    Text("\(FrenchFormat.height(event.height)) m")
                        .font(OceanTypography.caption)
                        .foregroundStyle(OceanPalette.white.opacity(0.9))
                        .fixedSize()
                }
                .position(x: anchorX, y: anchorY - markerSize - 4)
        }
    }

    private func hours(_ date: Date) -> Double {
        date.timeIntervalSince(dayStart) / 3600
    }
}

#Preview("Marée — journée") {
    TideChartCard(
        curve: PreviewTide.curve,
        events: PreviewTide.events,
        goodWindows: [PreviewTide.goodWindow],
        nextEventLine: "Basse 14 h 12 · 1,2 m",
        windowLine: "Bon créneau 13 h 10 à 15 h 40",
        timeZone: PreviewTide.timeZone,
        now: PreviewTide.now,
        accessibilitySentence: "Marée. Marée basse à 14 h 12, 1,2 mètres. Bon créneau 13 h 10 à 15 h 40.")
        .padding(OceanSpacing.md)
        .background(OceanPalette.backgroundGradient.ignoresSafeArea())
}

/// Hard-coded samples: a semi-diurnal day (UTC+1, 2026-10-26), low 14 h 12, window 13 h 10–15 h 40.
private enum PreviewTide {
    static let timeZone = TimeZone(secondsFromGMT: 3600) ?? TimeZone.gmt

    static let dayStart: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: 26))
            ?? Date(timeIntervalSince1970: 0)
    }()

    static let now = dayStart.addingTimeInterval(12 * 3600 + 52 * 60)

    /// 144 ten-minute samples over the local day.
    static let curve: [TidePoint] = (0 ..< 144).map { index in
        let hours = Double(index) / 6
        let height = 2.20 - 1.02 * cos(2 * Double.pi * (hours - 14.20) / 12.42)
        return TidePoint(time: dayStart.addingTimeInterval(hours * 3600), height: height)
    }

    static let events = [
        TideEvent(time: dayStart.addingTimeInterval(1 * 3600 + 48 * 60), kind: .low, height: 1.18),
        TideEvent(time: dayStart.addingTimeInterval(8 * 3600 + 2 * 60), kind: .high, height: 3.22),
        TideEvent(time: dayStart.addingTimeInterval(14 * 3600 + 12 * 60), kind: .low, height: 1.18),
        TideEvent(time: dayStart.addingTimeInterval(20 * 3600 + 25 * 60), kind: .high, height: 3.22)
    ]

    static let goodWindow = DateInterval(
        start: dayStart.addingTimeInterval(13 * 3600 + 10 * 60),
        end: dayStart.addingTimeInterval(15 * 3600 + 40 * 60))
}
