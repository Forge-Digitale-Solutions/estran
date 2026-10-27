#if DEBUG
    import EstranCore
    import Foundation

    /// DEBUG-only provider used to build the definitive UI before M2 ships.
    ///
    /// Two rules make it safe:
    ///
    /// 1. **It produces real `Conditions` values.** The tide is the *actual*
    ///    embedded REFMAR-derived model, not a mock; only the weather is
    ///    synthetic. The decision engine, the rules and the uncertainty gate run
    ///    unchanged, so what the UI shows is what the real engine would say for
    ///    those inputs.
    /// 2. **It never exists in release.** The whole file is inside `#if DEBUG`,
    ///    and `isSampleData == true` is what lights the « Données d'exemple »
    ///    badge.
    struct DemoConditionsProvider: ConditionsProviding {
        let isSampleData = true

        private let engine: TideEngine?

        init() {
            engine = try? ShippedTideModel.load().engine()
        }

        func conditions(for spot: Spot, at date: Date) async throws -> Conditions {
            guard let engine else { throw ConditionsProviderError.tideUnavailable }

            let tide: TideState
            do {
                tide = try await engine.state(for: spot.tideStation.id, at: date)
            } catch {
                throw ConditionsProviderError.tideUnavailable
            }

            return Conditions(
                spot: spot,
                at: date,
                tide: tide,
                weather: DemoWeather.weather(for: spot, at: date),
                swell: DemoWeather.swell(for: spot, at: date))
        }

        func forecast(for spot: Spot, from date: Date, hours: Int) async throws -> [Conditions] {
            var samples: [Conditions] = []
            samples.reserveCapacity(hours)
            for hour in 0 ..< max(hours, 1) {
                let instant = date.addingTimeInterval(Double(hour) * 3600)
                try await samples.append(conditions(for: spot, at: instant))
            }
            return samples
        }
    }

    /// Deterministic synthetic weather, stable within an hour and per spot.
    ///
    /// Determinism matters for previews and screenshots: the same spot and hour
    /// always produce the same values, so a UI regression is reproducible.
    private enum DemoWeather {
        static func weather(for spot: Spot, at date: Date) -> WeatherNow {
            let seed = seed(for: spot, at: date)
            let condition = conditions[Int(noise(seed &+ 7) * Double(conditions.count))
                % conditions.count]
            let speed = 5 + 17 * noise(seed &+ 1)

            return WeatherNow(
                temperature: 15 + 8 * noise(seed &+ 2),
                condition: condition,
                precipitationChance: condition == .showers ? 0.4 : 0.05,
                cloudCover: 0.15 + 0.7 * noise(seed &+ 3),
                wind: Wind(
                    speed: speed,
                    gust: speed * 1.4,
                    directionDegrees: 230 + 70 * noise(seed &+ 4)),
                visibility: 10000 + 10000 * noise(seed &+ 5))
        }

        static func swell(for spot: Spot, at date: Date) -> Swell {
            let seed = seed(for: spot, at: date)
            return Swell(
                waveHeight: 0.4 + 1.4 * noise(seed &+ 11),
                period: 8 + 5 * noise(seed &+ 12),
                directionDegrees: 250 + 50 * noise(seed &+ 13),
                seaSurfaceTemperature: 17 + 2.5 * noise(seed &+ 14))
        }

        private static let conditions: [WeatherCondition] = [
            .clear, .partlyCloudy, .cloudy, .showers
        ]

        private static func seed(for spot: Spot, at date: Date) -> UInt64 {
            let hour = UInt64(bitPattern: Int64(date.timeIntervalSince1970 / 3600))
            let spotSeed = spot.id.utf8.reduce(UInt64(0)) { $0 &* 31 &+ UInt64($1) }
            return hour &* 0x9E37_79B9_7F4A_7C15 &+ spotSeed
        }

        /// SplitMix-style hash → [0, 1).
        private static func noise(_ seed: UInt64) -> Double {
            var value = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            value ^= value >> 33
            value = value &* 0xFF51_AFD7_ED55_8CCD
            value ^= value >> 33
            return Double(value % 10000) / 10000.0
        }
    }
#endif
