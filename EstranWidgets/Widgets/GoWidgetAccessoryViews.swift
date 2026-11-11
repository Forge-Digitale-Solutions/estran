import EstranCore
import SwiftUI
import WidgetKit

/// Lock Screen inline widget (`accessoryInline`).
///
/// Format: « Pêche : Non · Pluie », « Baignade : courants modérés · Baïnes »,
/// or « Estran : — · Ouvre l'app » when stale/missing.
struct GoAccessoryInlineView: View {
    let entry: GoEntry

    var body: some View {
        if entry.isSwimming {
            if entry.isEmpty || entry.isStale {
                Label(
                    "Baignade : baïnes · — · Ouvre l'app",
                    systemImage: "exclamationmark.triangle.fill")
            } else {
                Label(
                    "Baignade : courants \(entry.resolvedSwimmingLevel.shortTitle) · Baïnes",
                    systemImage: "exclamationmark.triangle.fill")
            }
        } else if entry.isEmpty || entry.isStale {
            Label("Estran : — · Ouvre l'app", systemImage: "water.waves")
        } else if entry.isUnavailable {
            Label(
                "\(entry.shortActivityLabel) : — · Indisponible",
                systemImage: "exclamationmark.triangle.fill")
        } else {
            let verdict = entry.isGo ? "Oui" : "Non"
            Label(
                "\(entry.shortActivityLabel) : \(verdict) · \(entry.detail)",
                systemImage: entry.activitySymbol)
        }
    }
}

/// Lock Screen circular widget (`accessoryCircular`).
///
/// Shows the verdict or swimming risk + « Baïnes » inside an
/// `AccessoryWidgetBackground`. Never shows « Oui » for swimming (Invariant 1),
/// and renders « — » when missing or stale (Invariant 3).
struct GoAccessoryCircularView: View {
    let entry: GoEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            if entry.isSwimming {
                swimmingCircular
            } else if entry.isEmpty || entry.isStale {
                staleOrEmptyCircular
            } else if entry.isUnavailable {
                unavailableCircular
            } else {
                standardCircular
            }
        }
    }

    private var swimmingCircular: some View {
        let level = entry.resolvedSwimmingLevel
        let levelText = (entry.isEmpty || entry.isStale) ? "—" : level.shortTitle.capitalized
        return VStack(spacing: 1) {
            Image(systemName: "exclamationmark.triangle.fill")
                .widgetAccentedRenderingMode(.accentedDesaturated)
                .font(OceanTypography.smallLabel)
                .widgetAccentable()
                .accessibilityHidden(true)

            Text(levelText)
                .font(OceanTypography.tabLabel)
                .widgetAccentable()
                .minimumScaleFactor(0.7)

            Text("Baïnes")
                .font(OceanTypography.smallLabel)
                .minimumScaleFactor(0.75)
        }
        .padding(4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            entry.isEmpty || entry.isStale
                ? "Baignade : danger baïnes toute l'année. Données indisponibles, ouvre l'app."
                : "Baignade à \(entry.title) : courants \(level.shortTitle). Danger baïnes toute l'année.")
    }

    private var staleOrEmptyCircular: some View {
        VStack(spacing: 1) {
            Image(systemName: "water.waves")
                .widgetAccentedRenderingMode(.accentedDesaturated)
                .font(OceanTypography.smallLabel)
                .accessibilityHidden(true)

            Text("—")
                .font(OceanTypography.bodyEmphasized)
                .widgetAccentable()

            Text("Ouvre l'app")
                .font(OceanTypography.smallLabel)
                .minimumScaleFactor(0.65)
        }
        .padding(4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Estran : —. Ouvre l'app pour charger les conditions.")
    }

    private var unavailableCircular: some View {
        VStack(spacing: 1) {
            Image(systemName: "exclamationmark.triangle.fill")
                .widgetAccentedRenderingMode(.accentedDesaturated)
                .font(OceanTypography.smallLabel)
                .widgetAccentable()
                .accessibilityHidden(true)

            Text("—")
                .font(OceanTypography.bodyEmphasized)
                .widgetAccentable()

            Text(entry.shortActivityLabel)
                .font(OceanTypography.smallLabel)
                .minimumScaleFactor(0.75)
        }
        .padding(4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(entry.activityDisplayName) à \(entry.title) : données indisponibles.")
    }

    private var standardCircular: some View {
        let verdict = entry.isGo ? "Oui" : "Non"
        return VStack(spacing: 1) {
            Image(systemName: entry.verdictSymbol)
                .widgetAccentedRenderingMode(.accentedDesaturated)
                .font(OceanTypography.smallLabel)
                .widgetAccentable()
                .accessibilityHidden(true)

            Text(verdict)
                .font(OceanTypography.bodyEmphasized)
                .widgetAccentable()

            Text(entry.shortActivityLabel)
                .font(OceanTypography.smallLabel)
                .minimumScaleFactor(0.75)
        }
        .padding(4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(verdict), \(entry.activityDisplayName) à \(entry.title). \(entry.detail)")
    }
}

/// Lock Screen rectangular widget (`accessoryRectangular`).
struct GoAccessoryRectangularView: View {
    let entry: GoEntry

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.levelOfDetail) private var levelOfDetail

    var body: some View {
        Group {
            if entry.isSwimming {
                swimmingRectangular
            } else if entry.isEmpty || entry.isStale {
                staleOrEmptyRectangular
            } else if entry.isUnavailable {
                unavailableRectangular
            } else {
                standardRectangular
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var swimmingRectangular: some View {
        let level = entry.resolvedSwimmingLevel
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .widgetAccentedRenderingMode(.accentedDesaturated)
                    .font(OceanTypography.smallLabel)
                    .widgetAccentable()
                    .accessibilityHidden(true)

                Text("Baignade · \(entry.title)")
                    .font(OceanTypography.tabLabel)
                    .widgetAccentable()
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(entry.isEmpty || entry.isStale
                ? "— · Ouvre l'app"
                : "Courants : \(level.shortTitle)")
                .font(OceanTypography.smallLabel)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)

            Text("Danger baïnes toute l'année")
                .font(OceanTypography.smallLabel)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var staleOrEmptyRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "water.waves")
                    .widgetAccentedRenderingMode(.accentedDesaturated)
                    .font(OceanTypography.smallLabel)
                    .widgetAccentable()
                    .accessibilityHidden(true)

                Text(entry.title)
                    .font(OceanTypography.tabLabel)
                    .widgetAccentable()
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("— · Ouvre l'app")
                .font(OceanTypography.bodyEmphasized)
                .widgetAccentable()
                .fixedSize(horizontal: false, vertical: true)

            if levelOfDetail != .simplified {
                Text(entry.isStale ? "Données de plus de 2 h" : "Conditions non chargées")
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var unavailableRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(entry.shortActivityLabel) · \(entry.title)")
                .font(OceanTypography.tabLabel)
                .widgetAccentable()
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .widgetAccentedRenderingMode(.accentedDesaturated)
                    .font(OceanTypography.smallLabel)
                    .widgetAccentable()
                    .accessibilityHidden(true)
                Text("— · Données indisponibles")
                    .font(OceanTypography.smallLabel)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if levelOfDetail != .simplified {
                Text("Ouvre l'app")
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var standardRectangular: some View {
        let verdict = entry.isGo ? "Oui" : "Non"
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: entry.activitySymbol)
                    .widgetAccentedRenderingMode(.accentedDesaturated)
                    .font(OceanTypography.smallLabel)
                    .accessibilityHidden(true)

                Text("\(entry.shortActivityLabel) · \(entry.title)")
                    .font(OceanTypography.tabLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: entry.verdictSymbol)
                    .widgetAccentedRenderingMode(.accentedDesaturated)
                    .font(OceanTypography.smallLabel)
                    .widgetAccentable()
                    .accessibilityHidden(true)

                Text(verdict)
                    .font(OceanTypography.bodyEmphasized)
                    .widgetAccentable()

                Text("· \(entry.detail)")
                    .font(OceanTypography.smallLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if levelOfDetail != .simplified,
               !dynamicTypeSize.isAccessibilitySize,
               let metricsLine = entry.compactMetricsLine
            {
                Text(metricsLine)
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
