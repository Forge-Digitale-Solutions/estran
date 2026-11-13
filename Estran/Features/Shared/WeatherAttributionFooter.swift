import SwiftUI
import UIKit

/// The weather credit a source actually requires, drawn where its values are.
///
/// **Apple.** WeatherKit's terms ask for the Apple Weather mark and a link to
/// its legal page wherever its data is displayed. The app is dark-only, so the
/// combined **dark** mark is the one used.
///
/// **Open-Meteo.** CC BY 4.0: the name and the licence link, because the
/// fallback is a real source too, not a silent substitute.
///
/// **Sample data.** No external provider answered, so nothing is credited; the
/// « Données d'exemple » badge already says where the values come from.
///
/// The mark is loaded by `WeatherAttributionStore`; when the call or the image
/// fails, the credit degrades to the text « Météo : Apple Météo » and keeps the
/// legal link whenever the attribution itself succeeded. A broken image is
/// never drawn.
struct WeatherAttributionFooter: View {
    /// The spot whose weather is on screen: the source is recorded per spot.
    let spotID: String

    var store: WeatherAttributionStore = .shared

    @ScaledMetric(relativeTo: .caption2) private var markHeight: CGFloat = 16

    var body: some View {
        if let source = store.source(forSpotID: spotID) {
            VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
                sourceLine(source)
                legalLink(source)
            }
            .task {
                // Only an Apple credit needs the mark; the fallback never calls
                // WeatherKit's attribution endpoint.
                guard source == .appleWeather else { return }
                await store.loadAppleAttributionIfNeeded()
            }
        }
    }

    // MARK: - Source

    @ViewBuilder
    private func sourceLine(_ source: WeatherSourceKind) -> some View {
        switch source {
        case .appleWeather:
            if let image = markImage {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(height: markHeight)
                    .accessibilityLabel("Météo : Apple Météo")
                    .accessibilityAddTraits(.isImage)
            } else {
                sourceText("Météo : Apple Météo")
            }
        case .openMeteo:
            sourceText("Météo : Open-Meteo · CC BY 4.0")
        }
    }

    @ViewBuilder
    private func legalLink(_ source: WeatherSourceKind) -> some View {
        switch source {
        case .appleWeather:
            if let url = store.legalPageURL {
                legalButton("Sources légales", url)
            }
        case .openMeteo:
            if let url = WeatherAttributionLinks.openMeteoLicence {
                legalButton("Licence CC BY 4.0", url)
            }
        }
    }

    // MARK: - Pieces

    private func sourceText(_ text: String) -> some View {
        Text(text)
            .font(OceanTypography.smallLabel)
            .foregroundStyle(OceanPalette.white.opacity(0.6))
            .fixedSize(horizontal: false, vertical: true)
    }

    /// A text link with the HIG's 44 pt tap height: a legal credit the user
    /// cannot reliably hit is not a credit.
    private func legalButton(_ title: String, _ url: URL) -> some View {
        Link(destination: url) {
            Text(title)
                .font(OceanTypography.smallLabel)
                .foregroundStyle(OceanPalette.turquoiseOnGlass)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: OceanGlass.minimumTapHeight, alignment: .leading)
                .contentShape(Rectangle())
        }
    }

    /// The combined dark mark, decoded on demand. `nil` while it loads and
    /// after a failed download, so the text fallback stays.
    private var markImage: Image? {
        guard let data = store.markImageData, let uiImage = UIImage(data: data) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
}

/// Static legal destinations, checked once instead of force-unwrapped.
enum WeatherAttributionLinks {
    /// CC BY 4.0, the licence Open-Meteo publishes its forecast under.
    static let openMeteoLicence = URL(string: "https://creativecommons.org/licenses/by/4.0/")
}
