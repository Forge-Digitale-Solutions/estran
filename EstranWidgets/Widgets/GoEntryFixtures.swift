import EstranCore
import Foundation
import SwiftUI

extension GoEntry {
    /// `true` when no snapshot was found in the App Group (placeholder state).
    var isEmpty: Bool {
        answer == "—" && lines.isEmpty && metrics.isEmpty && !isSwimming
    }

    /// `true` when the snapshot is older than `WidgetSnapshot.staleAfter` (2 h).
    ///
    /// Stale data must never present a past `Oui` as current (invariants 3 & 4).
    var isStale: Bool {
        !isEmpty && Date().timeIntervalSince(date) > WidgetSnapshot.staleAfter
    }

    /// Resolves the selected activity from `selectedActivity`, `isSwimming`, or
    /// the matching `ActivityLine` in `lines`.
    var resolvedActivity: Activity? {
        if let selectedActivity {
            return selectedActivity
        }
        if isSwimming {
            return .swimming
        }
        if let exact = lines.first(where: {
            $0.activity != .swimming
                && $0.answer == detail
                && $0.isGo == isGo
                && $0.isUnavailable == isUnavailable
        }) {
            return exact.activity
        }
        return lines.first { $0.answer == detail }?.activity
    }

    /// The deep link a tap opens: the configured spot + activity, so the app
    /// lands on exactly what the widget shows. `nil` for the bare placeholder.
    var openURL: URL? {
        guard !spotID.isEmpty, let activity = resolvedActivity else { return nil }
        return WidgetDeepLink.url(spotID: spotID, activity: activity)
    }

    var shortActivityLabel: String {
        resolvedActivity?.shortLabel ?? (isSwimming ? Activity.swimming.shortLabel : "Pêche")
    }

    var activityDisplayName: String {
        resolvedActivity?.displayName ?? (isSwimming ? Activity.swimming.displayName : "Pêche à pied")
    }

    var activitySymbol: String {
        resolvedActivity?.symbolName ?? (isSwimming ? Activity.swimming.symbolName : "water.waves")
    }

    var resolvedSwimmingLevel: SwimmingRiskLevel {
        if let level = swimmingAdvisory?.level {
            return level
        }
        if let lineLevel = lines.first(where: { $0.activity == .swimming })?.swimmingLevel {
            return lineLevel
        }
        return .unknown
    }

    var resolvedSwimmingAdvisory: SwimmingAdvisory {
        swimmingAdvisory ?? SwimmingAdvisory(
            level: resolvedSwimmingLevel,
            region: .bassin)
    }

    /// Display colour for the large verdict badge. Never green for swimming,
    /// `Non`, unavailable, missing or stale states, and never a verdict colour
    /// for a not-offered activity.
    var verdictColor: Color {
        if isSwimming {
            return OceanPalette.swimmingRiskText(resolvedSwimmingLevel)
        }
        if isNotOffered {
            return OceanPalette.sand
        }
        if isEmpty || isStale || isUnavailable {
            return OceanPalette.unavailable
        }
        return isGo ? OceanPalette.oui : OceanPalette.non
    }

    /// Small-text colour (≥ 4.5:1 on glass/gradient).
    var verdictOnGlassColor: Color {
        if isSwimming {
            return OceanPalette.swimmingRiskText(resolvedSwimmingLevel)
        }
        if isNotOffered {
            return OceanPalette.sand
        }
        if isEmpty || isStale || isUnavailable {
            return OceanPalette.unavailable
        }
        return isGo ? OceanPalette.ouiOnGlass : OceanPalette.nonOnGlass
    }

    var verdictSymbol: String {
        if isSwimming {
            return "exclamationmark.triangle.fill"
        }
        if isNotOffered {
            return resolvedActivity?.symbolName ?? "figure.surfing"
        }
        if isEmpty || isStale {
            return "clock.badge.exclamationmark"
        }
        if isUnavailable {
            return "exclamationmark.triangle.fill"
        }
        return isGo ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    /// Colour for one row in the five-activity list. Never green for swimming.
    func lineColor(for line: WidgetSnapshot.ActivityLine) -> Color {
        if line.activity == .swimming {
            return line.swimmingLevel.map(OceanPalette.swimmingRiskText) ?? OceanPalette.sand
        }
        if line.isUnavailable {
            return OceanPalette.unavailable
        }
        return line.isGo ? OceanPalette.ouiOnGlass : OceanPalette.nonOnGlass
    }

    /// Enforces Invariant 1 on activity lines: swimming never shows « Oui ».
    func safeLineAnswer(for line: WidgetSnapshot.ActivityLine) -> String {
        if line.activity == .swimming {
            let trimmed = line.answer.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.localizedCaseInsensitiveCompare("oui") == .orderedSame {
                return (line.swimmingLevel ?? .unknown).label
            }
            if let level = line.swimmingLevel {
                return "Courants \(level.shortTitle) · Baïnes"
            }
        }
        return line.answer
    }

    /// Compact one-line summary of the first two metrics (tide + wind) for
    /// rectangular Lock Screen widgets.
    var compactMetricsLine: String? {
        guard !isEmpty, !isStale, !metrics.isEmpty else { return nil }
        let items = metrics.prefix(2).map { "\($0.value) \($0.caption)" }
        return items.isEmpty ? nil : items.joined(separator: " · ")
    }

    // MARK: - Preview Fixtures

    static let sampleLines: [WidgetSnapshot.ActivityLine] = [
        WidgetSnapshot.ActivityLine(
            activity: .shoreFishing,
            isUnavailable: false,
            isGo: false,
            answer: "Pluie"),
        WidgetSnapshot.ActivityLine(
            activity: .surfing,
            isUnavailable: false,
            isGo: true,
            answer: "14 h 00 à 17 h 30"),
        WidgetSnapshot.ActivityLine(
            activity: .boating,
            isUnavailable: false,
            isGo: true,
            answer: "13 h 30 à 18 h 00"),
        WidgetSnapshot.ActivityLine(
            activity: .walking,
            isUnavailable: false,
            isGo: false,
            answer: "Pluie"),
        WidgetSnapshot.ActivityLine(
            activity: .swimming,
            isUnavailable: false,
            isGo: false,
            answer: SwimmingRiskLevel.moderate.label,
            warning: SwimmingRiskLevel.moderate.widgetWarning(for: .medoc),
            swimmingLevel: .moderate)
    ]

    static let sampleMetrics: [WidgetSnapshot.Metric] = [
        WidgetSnapshot.Metric(
            id: "tide",
            symbol: "water.waves.and.arrow.trianglehead.down",
            value: "1,8 m",
            caption: "baisse"),
        WidgetSnapshot.Metric(
            id: "wind",
            symbol: "wind",
            value: "14",
            caption: "km/h NO"),
        WidgetSnapshot.Metric(
            id: "swell",
            symbol: "water.waves",
            value: "1,2 m",
            caption: "11 s"),
        WidgetSnapshot.Metric(
            id: "weather",
            symbol: "cloud.rain.fill",
            value: "17 °C",
            caption: "pluie")
    ]

    static let sample = GoEntry(
        date: Date(),
        title: "Pointe de Grave",
        answer: "Oui",
        detail: "14 h 00 à 17 h 30",
        isSwimming: false,
        swimmingAdvisory: nil,
        isGo: true,
        isUnavailable: false,
        lines: sampleLines,
        metrics: sampleMetrics,
        isSampleData: true,
        selectedActivity: .surfing)

    static let sampleNoGo = GoEntry(
        date: Date(),
        title: "Arcachon-Eyrac",
        answer: "Non",
        detail: "Pluie",
        isSwimming: false,
        swimmingAdvisory: nil,
        isGo: false,
        isUnavailable: false,
        lines: sampleLines,
        metrics: sampleMetrics,
        isSampleData: true,
        selectedActivity: .shoreFishing)

    static let sampleSwimming = GoEntry(
        date: Date(),
        title: "Pointe de Grave",
        answer: SwimmingRiskLevel.moderate.shortTitle,
        detail: SwimmingRiskLevel.moderate.label,
        isSwimming: true,
        swimmingAdvisory: SwimmingAdvisory(
            level: .moderate,
            region: .medoc,
            conditionsLine: "Vent 14 km/h · houle 1,2 m · eau 17 °C",
            notes: ["eau froide", "pluie"]),
        isGo: false,
        isUnavailable: false,
        lines: sampleLines,
        metrics: sampleMetrics,
        isSampleData: true,
        selectedActivity: .swimming)

    static let sampleStale = GoEntry(
        date: Date().addingTimeInterval(-(WidgetSnapshot.staleAfter + 1800)),
        title: "Arcachon-Eyrac",
        answer: "Oui",
        detail: "13 h 10 à 15 h 40",
        isSwimming: false,
        swimmingAdvisory: nil,
        isGo: true,
        isUnavailable: false,
        lines: sampleLines,
        metrics: sampleMetrics,
        isSampleData: true,
        selectedActivity: .shoreFishing)
}
