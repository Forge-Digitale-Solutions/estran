import SwiftUI

/// The weather credit under the conditions of the large widget and the
/// Conditions widget.
///
/// Apple WeatherKit's terms require the Apple Weather mark wherever its data
/// is displayed, and Open-Meteo asks for a CC BY 4.0 credit. A widget has no
/// room for the mark image, so the source is named in text — the shortest form
/// that still says who supplied the numbers. Small and Lock Screen families
/// draw no credit: they show no weather value of their own (the accessory
/// families show the verdict and the tide only).
///
/// `nil` (sample data, or a snapshot written before the record existed) draws
/// nothing rather than crediting the wrong party.
struct WidgetWeatherCredit: View {
    let source: WeatherSourceKind?
    let isSampleData: Bool

    var body: some View {
        if let source, !isSampleData {
            Text("Météo : \(source.displayName)")
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Source météo : \(source.displayName)")
        }
    }
}
