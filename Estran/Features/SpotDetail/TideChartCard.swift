import Charts
import EstranCore
import Foundation
import SwiftUI

/// Frame 02 — the tide chart card (Swift Charts).
///
/// Never invents a value: an empty `curve` renders « Données indisponibles »,
/// never a flat line at 0. Scrubbing snaps to nearest real samples only. The
/// card is one accessibility element labelled with `accessibilitySentence`.
struct TideChartCard: View {
    let curve: [TidePoint]
    let events: [TideEvent]
    let goodWindows: [DateInterval]
    let nextEventLine: String?
    let windowLine: String?
    let timeZone: TimeZone
    let now: Date
    let accessibilitySentence: String

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
                Text("Données indisponibles")
                    .font(OceanTypography.body)
                    .foregroundStyle(OceanPalette.unavailable)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, OceanSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TideChartPlot(
                    curve: curve,
                    events: events,
                    goodWindows: goodWindows,
                    timeZone: timeZone,
                    now: now)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(OceanSpacing.md)
        .oceanGlassCard(cornerRadius: OceanGlass.cardCornerRadius)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySentence)
    }

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
}

// MARK: - Plot + scrub

/// Interactive tide plot: curve, « maintenant » rule, scrub selection, haptics.
private struct TideChartPlot: View {
    let curve: [TidePoint]
    let events: [TideEvent]
    let goodWindows: [DateInterval]
    let timeZone: TimeZone
    let now: Date

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 132
    @ScaledMetric(relativeTo: .body) private var markerSize: CGFloat = 9
    @State private var selectedHour: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xs) {
            scrubCallout
            chart
        }
        .sensoryFeedback(.selection, trigger: scrubSampleIndex)
    }

    @ViewBuilder
    private var scrubCallout: some View {
        if let point = selectedPoint {
            HStack(spacing: OceanSpacing.xs) {
                Text(FrenchFormat.time(point.time, in: timeZone))
                    .contentTransition(reduceMotion ? .identity : .numericText())
                Text("·").accessibilityHidden(true)
                Text("\(FrenchFormat.height(point.height)) m")
                    .contentTransition(reduceMotion ? .identity : .numericText())
            }
            .font(OceanTypography.caption.weight(.semibold))
            .foregroundStyle(OceanPalette.white)
            .padding(.horizontal, OceanSpacing.sm)
            .padding(.vertical, OceanSpacing.xxs)
            .oceanGlassCapsule()
            .animation(
                OceanGlass.animation(.smooth, reduceMotion: reduceMotion),
                value: scrubSampleIndex)
            .accessibilityHidden(true)
        }
    }

    private var chart: some View {
        Chart {
            ForEach(goodWindows.indices, id: \.self) { index in
                let window = goodWindows[index]
                RectangleMark(
                    xStart: .value("Début du créneau", hours(window.start)),
                    xEnd: .value("Fin du créneau", hours(window.end)))
                    .foregroundStyle(OceanPalette.chartHighlight.opacity(0.18))
            }
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
            if let point = nowPoint {
                RuleMark(x: .value("Maintenant", hours(now)))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(OceanPalette.white.opacity(0.7))
                PointMark(
                    x: .value("Maintenant", hours(now)),
                    y: .value("Hauteur", point.height))
                    .symbol {
                        Circle()
                            .fill(OceanPalette.turquoise)
                            .overlay { Circle().strokeBorder(OceanPalette.white, lineWidth: 2) }
                            .frame(width: markerSize, height: markerSize)
                    }
            }
            if let point = selectedPoint {
                RuleMark(x: .value("Sélection", hours(point.time)))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .foregroundStyle(OceanPalette.white.opacity(0.55))
                PointMark(
                    x: .value("Sélection", hours(point.time)),
                    y: .value("Hauteur", point.height))
                    .symbol {
                        Circle()
                            .fill(OceanPalette.white)
                            .frame(width: markerSize * 0.9, height: markerSize * 0.9)
                    }
            }
            if let event = nextEvent {
                PointMark(
                    x: .value("Prochaine marée", hours(event.time)),
                    y: .value("Hauteur", event.height))
                    .symbol {
                        Circle()
                            .strokeBorder(OceanPalette.white, lineWidth: 1.5)
                            .frame(width: markerSize * 0.8, height: markerSize * 0.8)
                    }
            }
        }
        .chartXScale(domain: 0 ... 24)
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartXSelection(value: scrubSelection)
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

    private var scrubSelection: Binding<Double?> {
        voiceOverEnabled ? .constant(nil) : $selectedHour
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

    private var axisHours: [Double] {
        dynamicTypeSize.isAccessibilitySize ? [0, 12, 24] : [0, 6, 12, 18, 24]
    }

    private var dayStart: Date {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        return gregorian.startOfDay(for: now)
    }

    private func hours(_ date: Date) -> Double {
        date.timeIntervalSince(dayStart) / 3600
    }

    private var yDomain: ClosedRange<Double> {
        let heights = curve.map(\.height)
        guard let low = heights.min(), let high = heights.max() else { return 0 ... 1 }
        let span = max(high - low, 0.4)
        return (low - span * 0.2) ... (high + span * 0.35)
    }

    private var selectedPoint: TidePoint? {
        guard let selectedHour, !curve.isEmpty else { return nil }
        return curve.min {
            abs(hours($0.time) - selectedHour) < abs(hours($1.time) - selectedHour)
        }
    }

    private var scrubSampleIndex: Int {
        guard let point = selectedPoint,
              let index = curve.firstIndex(where: { $0.time == point.time })
        else { return -1 }
        return index
    }

    private var nowPoint: TidePoint? {
        guard hours(now) >= 0, hours(now) <= 24,
              let first = curve.first, let last = curve.last,
              now >= first.time, now <= last.time
        else { return nil }
        if let exact = curve.first(where: { $0.time == now }) {
            return exact
        }
        guard let upperIndex = curve.firstIndex(where: { $0.time > now }), upperIndex > 0
        else { return nil }
        let lower = curve[upperIndex - 1]
        let upper = curve[upperIndex]
        let span = upper.time.timeIntervalSince(lower.time)
        guard span > 0 else { return nil }
        let fraction = now.timeIntervalSince(lower.time) / span
        return TidePoint(
            time: now,
            height: lower.height + (upper.height - lower.height) * fraction)
    }

    private var nextEvent: TideEvent? {
        events
            .filter { $0.time >= now && hours($0.time) <= 24 }
            .min { $0.time < $1.time }
    }
}

/// Hour scale and next-event height, drawn over the plot via `ChartProxy`.
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
        .background { OceanBackdrop() }
}

private enum PreviewTide {
    static let timeZone = TimeZone(secondsFromGMT: 3600) ?? TimeZone.gmt

    static let dayStart: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: 26))
            ?? Date(timeIntervalSince1970: 0)
    }()

    static let now = dayStart.addingTimeInterval(12 * 3600 + 52 * 60)

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
