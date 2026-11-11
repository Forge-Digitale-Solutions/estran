import EstranCore
import SwiftUI
import WidgetKit

/// `.systemLarge` layout for `GoWidget`: spot header, hero verdict (or swimming
/// advisory), the five activity lines, and the four conditions metrics in
/// concentric Liquid Glass cards.
struct GoWidgetLargeView: View {
    let entry: GoEntry

    @ScaledMetric(relativeTo: .largeTitle) private var badgeSize: CGFloat =
        OceanTypography.widgetGoBadgeBaseSize

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.levelOfDetail) private var levelOfDetail

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            axFallbackBody
        } else if entry.isEmpty || entry.isStale {
            staleOrEmptyBody
        } else if entry.isSwimming {
            swimmingLargeBody
        } else {
            standardLargeBody
        }
    }
}

extension GoWidgetLargeView {
    // MARK: - Standard Large Layout

    private var standardLargeBody: some View {
        ViewThatFits(in: .vertical) {
            VStack(alignment: .leading, spacing: OceanSpacing.xs) {
                spotHeader
                heroVerdictCard
                if !entry.lines.isEmpty {
                    activityLinesCard
                }
                if !entry.metrics.isEmpty, levelOfDetail != .simplified {
                    metricsRow
                }
            }

            VStack(alignment: .leading, spacing: OceanSpacing.xs) {
                spotHeader
                heroVerdictCard
                if !entry.lines.isEmpty {
                    activityLinesCard
                }
            }

            axFallbackBody
        }
    }

    // MARK: - Swimming Large Layout (Invariant 1: never Oui, never green)

    private var swimmingLargeBody: some View {
        ViewThatFits(in: .vertical) {
            VStack(alignment: .leading, spacing: OceanSpacing.xs) {
                spotHeader
                swimmingAdvisoryCard
                if !entry.lines.isEmpty, levelOfDetail != .simplified {
                    activityLinesCard
                }
                if !entry.metrics.isEmpty, levelOfDetail != .simplified {
                    metricsRow
                }
            }

            VStack(alignment: .leading, spacing: OceanSpacing.xs) {
                spotHeader
                swimmingAdvisoryCard
                if !entry.metrics.isEmpty, levelOfDetail != .simplified {
                    metricsRow
                }
            }

            axSwimmingBody
        }
    }

    // MARK: - Stale / Missing Snapshot (Invariant 3 & 4)

    private var staleOrEmptyBody: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xs) {
            spotHeader

            VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
                HStack(spacing: OceanSpacing.xs) {
                    Image(systemName: entry.verdictSymbol)
                        .widgetAccentedRenderingMode(.accentedDesaturated)
                        .font(OceanTypography.metricValue)
                        .foregroundStyle(OceanPalette.unavailable)
                        .widgetAccentable()
                        .accessibilityHidden(true)

                    Text("—")
                        .font(OceanTypography.rounded(size: badgeSize * 0.72))
                        .foregroundStyle(OceanPalette.unavailable)
                        .widgetAccentable()
                }

                Text(entry.isStale
                    ? "Données de plus de 2 h · Ouvre l'app"
                    : "Ouvre l'app pour charger les conditions")
                    .font(OceanTypography.caption)
                    .foregroundStyle(OceanPalette.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(OceanSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetGlassCard(minimumRadius: 14)

            if entry.isSwimming {
                swimmingAdvisoryCard
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Subviews

    private var spotHeader: some View {
        HStack(spacing: OceanSpacing.xxs) {
            Image(systemName: "mappin.and.ellipse")
                .widgetAccentedRenderingMode(.accentedDesaturated)
                .font(OceanTypography.caption)
                .foregroundStyle(OceanPalette.turquoiseOnGlass)
                .widgetAccentable()
                .accessibilityHidden(true)

            Text(entry.title)
                .font(OceanTypography.caption)
                .foregroundStyle(OceanPalette.sand)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Image(systemName: entry.activitySymbol)
                    .widgetAccentedRenderingMode(.accentedDesaturated)
                    .font(OceanTypography.smallLabel)
                    .accessibilityHidden(true)
                Text(entry.activityDisplayName)
                    .font(OceanTypography.smallLabel)
            }
            .foregroundStyle(OceanPalette.white.opacity(0.88))
            .widgetAccentable()
        }
    }

    private var heroVerdictCard: some View {
        HStack(alignment: .center, spacing: OceanSpacing.sm) {
            HStack(spacing: OceanSpacing.xxs) {
                Image(systemName: entry.verdictSymbol)
                    .widgetAccentedRenderingMode(.accentedDesaturated)
                    .font(OceanTypography.metricValue)
                    .accessibilityHidden(true)
                Text(entry.isUnavailable ? "Données indisponibles" : entry.answer)
                    .font(OceanTypography.rounded(
                        size: entry.isUnavailable ? badgeSize * 0.44 : badgeSize * 0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(entry.verdictColor)
            .widgetAccentable()

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.activityDisplayName)
                    .font(OceanTypography.tabLabel)
                    .foregroundStyle(OceanPalette.sand)
                Text(entry.detail)
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.white.opacity(0.9))
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, OceanSpacing.sm)
        .padding(.vertical, OceanSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetGlassCard(minimumRadius: 14)
        .accessibilityElement(children: .combine)
    }

    private var swimmingAdvisoryCard: some View {
        let advisory = entry.resolvedSwimmingAdvisory
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: OceanSpacing.xxs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .widgetAccentedRenderingMode(.accentedDesaturated)
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.sand)
                    .widgetAccentable()
                    .accessibilityHidden(true)
                Text("Baignade · Courants : \(advisory.level.shortTitle)")
                    .font(OceanTypography.tabLabel)
                    .foregroundStyle(OceanPalette.swimmingRiskText(advisory.level))
                    .widgetAccentable()
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(advisory.level.widgetWarning(for: advisory.region))
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white)
                .fixedSize(horizontal: false, vertical: true)

            if let conditions = advisory.conditionsLine {
                let notesSuffix = advisory.notes.isEmpty
                    ? ""
                    : " · " + advisory.notes.joined(separator: " · ")
                Text(conditions + notesSuffix)
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            } else if !advisory.notes.isEmpty {
                Text(advisory.notes.joined(separator: " · "))
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.sand)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(SwimmingRiskLevel.disclaimer)
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(OceanSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetGlassCard(minimumRadius: 14)
        .accessibilityElement(children: .combine)
    }

    private var activityLinesCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(entry.lines) { line in
                HStack(spacing: OceanSpacing.xxs) {
                    Image(systemName: line.activity.symbolName)
                        .widgetAccentedRenderingMode(.accentedDesaturated)
                        .font(OceanTypography.smallLabel)
                        .foregroundStyle(OceanPalette.sand)
                        .frame(width: 14, alignment: .center)
                        .accessibilityHidden(true)

                    Text(line.activity.shortLabel)
                        .font(OceanTypography.smallLabel)
                        .foregroundStyle(OceanPalette.white.opacity(0.9))

                    Spacer(minLength: OceanSpacing.xxs)

                    Text(entry.safeLineAnswer(for: line))
                        .font(OceanTypography.smallLabel)
                        .foregroundStyle(entry.lineColor(for: line))
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, OceanSpacing.sm)
        .padding(.vertical, OceanSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetGlassCard(minimumRadius: 12)
    }

    private var metricsRow: some View {
        HStack(spacing: OceanSpacing.xxs) {
            ForEach(entry.metrics) { metric in
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 3) {
                        Image(systemName: metric.symbol)
                            .widgetAccentedRenderingMode(.accentedDesaturated)
                            .font(OceanTypography.smallLabel)
                            .foregroundStyle(OceanPalette.sand)
                            .widgetAccentable()
                            .accessibilityHidden(true)
                        Text(metric.value)
                            .font(OceanTypography.tabLabel)
                            .foregroundStyle(OceanPalette.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(metric.caption)
                        .font(OceanTypography.smallLabel)
                        .foregroundStyle(OceanPalette.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, OceanSpacing.xs)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .widgetGlassCard(minimumRadius: 10)
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - AX5 Fallback Layouts

    @ViewBuilder
    private var axFallbackBody: some View {
        if entry.isSwimming {
            axSwimmingBody
        } else {
            VStack(alignment: .leading, spacing: OceanSpacing.xs) {
                Text(entry.title)
                    .font(OceanTypography.caption)
                    .foregroundStyle(OceanPalette.sand)
                    .fixedSize(horizontal: false, vertical: true)

                Text(entry.isEmpty || entry.isStale ? "—" : entry.answer)
                    .font(OceanTypography.rounded(size: badgeSize * 0.75))
                    .foregroundStyle(entry.verdictColor)
                    .widgetAccentable()
                    .fixedSize(horizontal: false, vertical: true)

                Text(entry.isStale
                    ? "Données de plus de 2 h · Ouvre l'app"
                    : entry.detail)
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
        }
    }

    private var axSwimmingBody: some View {
        let advisory = entry.resolvedSwimmingAdvisory
        return VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
            Text(entry.title)
                .font(OceanTypography.caption)
                .foregroundStyle(OceanPalette.sand)
                .fixedSize(horizontal: false, vertical: true)

            Text("Baignade · Courants : \(advisory.level.shortTitle)")
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.swimmingRiskText(advisory.level))
                .widgetAccentable()
                .fixedSize(horizontal: false, vertical: true)

            Text(advisory.level.widgetWarning(for: advisory.region))
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(SwimmingRiskLevel.disclaimer)
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}
