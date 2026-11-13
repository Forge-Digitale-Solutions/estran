import Charts
import EstranCore
import Foundation
import SwiftUI

// Frame 02 preview: the tide card with a day of curve, one good window and
// the marnage line. Kept out of `TideChartCard.swift` so the card itself
// stays readable in one screen.

#Preview("Marée — journée") {
    TideChartCard(
        curve: PreviewTide.curve,
        events: PreviewTide.events,
        goodWindows: [PreviewTide.goodWindow],
        nextEventLine: "Basse 14 h 12 · 1,2 m",
        rangeLine: "Marnage 2,0 m · marée moyenne",
        windowLine: "Bon créneau 13 h 10 à 15 h 40",
        timeZone: PreviewTide.timeZone,
        now: PreviewTide.now,
        accessibilitySentence: "Marée. Marée basse à 14 h 12, 1,2 mètres. "
            + "Marnage 2,0 m · marée moyenne. Bon créneau 13 h 10 à 15 h 40.")
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
