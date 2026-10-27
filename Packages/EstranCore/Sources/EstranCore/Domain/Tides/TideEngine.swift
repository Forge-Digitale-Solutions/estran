import Foundation

/// Deterministic tide engine built on `HarmonicPredictor`.
///
/// No ambient clock is read anywhere: `date` is the only time input, so the
/// same station, date and set of stations always produce the same state.
public actor TideEngine: TidePredicting {
    private let stations: [String: TidalStation]
    /// Station whose range feeds the national coefficient (role
    /// `coefficientReference`). `nil` when the dataset has none, in which case
    /// the engine reports a local proxy and every gate that needs the national
    /// value fails closed.
    private let coefficientStation: TidalStation?
    private let coefficientValidated: Bool
    private let predictor = HarmonicPredictor()
    /// Extra hours searched beyond each local day so that `current` and
    /// `next` are always available near midnight.
    private let searchMargin: TimeInterval = 12 * 3600
    /// Interval between the samples of the day curve.
    private let curveStep: TimeInterval = 10 * 60
    /// Extra samples on each side of the local day, so a safety interval that
    /// crosses midnight is still fully covered.
    ///
    /// It must stay above the widest declared envelope (90 min for the post-v1
    /// lagoon bound, 60 min for the v1 Arcachon bound). `coversInterval` rejects
    /// an interval that still falls outside, so a larger envelope degrades to
    /// `.dataUnavailable`, never to a silent partial read.
    private let safetyMargin: TimeInterval = 2 * 3600

    /// - Parameters:
    ///   - stations: Every station the engine may predict.
    ///   - coefficientStationID: Identifier of the station whose range feeds
    ///     the national coefficient. Must be one of `stations` when present.
    ///   - coefficientValidated: `true` only when that coefficient model has
    ///     been validated against a published Annuaire sample.
    /// - Throws: `TideError.invalidStation` on the first station that does not
    ///   pass `TidalStation.validationError`, on a duplicate identifier, or on
    ///   an unknown coefficient station.
    public init(
        stations: [TidalStation],
        coefficientStationID: String? = nil,
        coefficientValidated: Bool = false) throws
    {
        var byIdentifier: [String: TidalStation] = [:]
        for station in stations {
            if let error = station.validationError {
                throw error
            }
            guard byIdentifier[station.id] == nil else {
                throw TideError.invalidStation("duplicate station id \(station.id)")
            }
            byIdentifier[station.id] = station
        }
        if let coefficientStationID {
            guard let station = byIdentifier[coefficientStationID] else {
                throw TideError.invalidStation(
                    "coefficient station \(coefficientStationID) is not registered")
            }
            coefficientStation = station
        } else {
            coefficientStation = nil
        }
        self.coefficientValidated = coefficientValidated
        self.stations = byIdentifier
    }

    /// Tide state for the given station data at `date`.
    ///
    /// Fails closed when `date` is past the station's `validUntil` horizon: the
    /// baseline model has no nodal corrections, so a prediction beyond the
    /// declared validity would silently decay.
    public func state(for station: TidalStation, at date: Date) async throws -> TideState {
        if let error = station.validationError {
            throw error
        }
        guard station.isValid(at: date) else {
            throw TideError.outsideValidity(station.id)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = station.timezone
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            throw TideError.invalidStation("cannot resolve local day for \(station.id)")
        }

        let events = predictor.extrema(
            for: station,
            from: dayStart.addingTimeInterval(-searchMargin),
            to: dayEnd.addingTimeInterval(searchMargin))
            .sorted { $0.time < $1.time }

        let current = events.last { $0.time <= date }
        let next = events.first { $0.time > date }

        // The national coefficient is defined at Brest, not at the spot's
        // station (review Z23). When the reference station is missing or past
        // its horizon, the engine falls back to the local proxy and every gate
        // that needs the national value fails closed.
        let coefficient: Int
        let coefficientSource: TideState.CoefficientSource
        let coefficientValidated: Bool
        if let coefficientStation, coefficientStation.isValid(at: date) {
            coefficient = predictor.nationalCoefficient(for: coefficientStation, on: date)
            coefficientSource = .nationalBrest
            coefficientValidated = self.coefficientValidated
        } else {
            coefficient = predictor.coefficient(for: station, on: date)
            coefficientSource = .localProxy
            coefficientValidated = false
        }

        let curve = dayCurve(for: station, from: dayStart, to: dayEnd)
        let safetyCurve = dayCurve(
            for: station,
            from: dayStart.addingTimeInterval(-safetyMargin),
            to: dayEnd.addingTimeInterval(safetyMargin))
        return TideState(
            current: current,
            next: next,
            coefficient: coefficient,
            coefficientSource: coefficientSource,
            coefficientValidated: coefficientValidated,
            curve: curve,
            safetyCurve: safetyCurve,
            validUntil: station.validUntil)
    }

    /// Tide state for a registered station at `date`.
    public func state(for stationID: String, at date: Date) async throws -> TideState {
        guard let station = stations[stationID] else {
            throw TideError.unknownStation(stationID)
        }
        return try await state(for: station, at: date)
    }

    /// The registered station with the given identifier, if any.
    public func station(id: String) -> TidalStation? {
        stations[id]
    }

    /// Every registered station, sorted by identifier.
    public func allStations() -> [TidalStation] {
        stations.values.sorted { $0.id < $1.id }
    }

    /// Curve sampled every 10 minutes over the local day: local start of day
    /// inclusive, next local start of day exclusive.
    private func dayCurve(for station: TidalStation, from dayStart: Date, to dayEnd: Date) -> [TidePoint] {
        var points: [TidePoint] = []
        var time = dayStart
        while time < dayEnd {
            points.append(TidePoint(time: time, height: predictor.height(for: station, at: time)))
            time = time.addingTimeInterval(curveStep)
        }
        return points
    }
}
