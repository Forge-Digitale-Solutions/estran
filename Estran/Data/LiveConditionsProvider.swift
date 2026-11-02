import EstranCore
import Foundation

/// Production conditions provider.
///
/// Three sources, composed here and nowhere else:
/// - **tide** — the embedded REFMAR-derived model, always available;
/// - **air weather** — WeatherKit (`WeatherKitService`), which needs the App ID
///   capability (`BUILD.md` §2);
/// - **swell and sea temperature** — Open-Meteo Marine, only where the model
///   describes the water (`MarinePolicy`).
///
/// **Fail closed, field by field.** A missing source throws; nothing is replaced
/// by a neutral value and a favourable verdict is never fabricated
/// (`worksplit.md` M2, `AGENTS.md` invariant 4). A forecast hour without swell is
/// skipped, so the window scanner never sees a made-up calm sea.
struct LiveConditionsProvider: ConditionsProviding {
    let isSampleData = false

    private let tideEngine: TideEngine?
    private let weather: any WeatherSource
    private let marine: MarineService

    /// A marine sample is used for an hour when it is within this window; hourly
    /// Open-Meteo samples are regular, so 90 min tolerates a DST step or a
    /// missing hour on both sides.
    private static let marineTolerance: TimeInterval = 90 * 60

    init(
        weather: any WeatherSource = FallbackWeatherSource(),
        marine: MarineService = MarineService())
    {
        tideEngine = try? ShippedTideModel.load().engine()
        self.weather = weather
        self.marine = marine
    }

    func conditions(for spot: Spot, at date: Date) async throws -> Conditions {
        guard let tideEngine else {
            throw ConditionsProviderError.tideUnavailable
        }
        let tide: TideState
        do {
            tide = try await tideEngine.state(for: spot.tideStation.id, at: date)
        } catch {
            throw ConditionsProviderError.tideUnavailable
        }

        let air = try await weather.weather(for: spot, at: date)
        let swell = try await swell(for: spot, at: date, weather: air)

        return Conditions(spot: spot, at: date, tide: tide, weather: air, swell: swell)
    }

    func forecast(for spot: Spot, from date: Date, hours: Int) async throws -> [Conditions] {
        guard let tideEngine else {
            throw ConditionsProviderError.tideUnavailable
        }
        let air = try await weather.forecast(for: spot, from: date, hours: hours)
        let swellSamples: [MarineSample] = switch MarinePolicy.source(for: spot) {
        case .offshoreModel: try await marine.samples(for: spot)
        case .windSeaEstimate: []
        }

        var samples: [Conditions] = []
        samples.reserveCapacity(air.count)
        for (index, weatherNow) in air.enumerated() {
            let instant = date.addingTimeInterval(Double(index) * 3600)
            guard let swell = swell(
                      for: spot,
                      at: instant,
                      weather: weatherNow,
                      samples: swellSamples),
                let tide = try? await tideEngine.state(for: spot.tideStation.id, at: instant)
            else {
                continue
            }
            samples.append(
                Conditions(
                    spot: spot,
                    at: instant,
                    tide: tide,
                    weather: weatherNow,
                    swell: swell))
        }

        guard !samples.isEmpty else {
            throw ConditionsProviderError.weatherUnavailable
        }
        return samples
    }

    // MARK: - Sea

    /// Sea state at `date`: the model where it describes the water, the wind-sea
    /// estimate elsewhere. A spot never silently uses the wrong one.
    private func swell(for spot: Spot, at date: Date, weather: WeatherNow) async throws -> Swell {
        switch MarinePolicy.source(for: spot) {
        case .offshoreModel:
            let samples = try await marine.samples(for: spot)
            guard let swell = Self.nearestSwell(in: samples, to: date) else {
                throw ConditionsProviderError.marineUnavailable
            }
            return swell
        case .windSeaEstimate:
            // The lagoon: waves from the measured wind, sea temperature left
            // unavailable because no source measures it there.
            return WindSeaEstimator.estimate(
                wind: weather.wind,
                fetchMeters: MarinePolicy.fetchMeters(for: spot))
        }
    }

    /// Same decision for one forecast hour, without another network call.
    private func swell(
        for spot: Spot,
        at date: Date,
        weather: WeatherNow,
        samples: [MarineSample]) -> Swell?
    {
        switch MarinePolicy.source(for: spot) {
        case .offshoreModel:
            Self.nearestSwell(in: samples, to: date)
        case .windSeaEstimate:
            WindSeaEstimator.estimate(
                wind: weather.wind,
                fetchMeters: MarinePolicy.fetchMeters(for: spot))
        }
    }

    /// The swell of the closest sample within the tolerance, or `nil`.
    static func nearestSwell(in samples: [MarineSample], to date: Date) -> Swell? {
        let nearest = samples
            .filter { abs($0.time.timeIntervalSince(date)) <= marineTolerance }
            .min { abs($0.time.timeIntervalSince(date)) < abs($1.time.timeIntervalSince(date)) }
        return nearest?.swell
    }
}
