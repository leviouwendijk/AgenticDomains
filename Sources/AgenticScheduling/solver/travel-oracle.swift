import Foundation

/// Resolves places and estimates travel once per distinct input during one
/// tool call, and collects what could not be resolved.
actor TravelOracle {
    enum Lookup: Sendable {
        case resolved(SchedulingPlace)
        case unresolved
    }

    private let resolver: any PlaceResolver
    private let estimator: any TravelEstimator
    let mode: TravelMode

    private var places: [String: Lookup] = [:]
    private var estimates: [String: TravelEstimate] = [:]
    private(set) var gaps: [String] = []

    init(resolver: any PlaceResolver, estimator: any TravelEstimator, mode: TravelMode) {
        self.resolver = resolver
        self.estimator = estimator
        self.mode = mode
    }

    func place(_ text: String) async -> Lookup {
        if let known = places[text] {
            return known
        }
        let lookup: Lookup
        do {
            if let place = try await resolver.resolve(text) {
                lookup = .resolved(place)
            } else {
                lookup = .unresolved
                note("Location '\(text)' could not be resolved; travel to or from it was not checked.")
            }
        } catch {
            lookup = .unresolved
            note("Resolving location '\(text)' failed (\(error.localizedDescription)); travel to or from it was not checked.")
        }
        places[text] = lookup
        return lookup
    }

    func place(of event: ScheduledEvent) async -> SchedulingPlace? {
        guard let text = event.locationText, case .resolved(let place) = await place(text) else {
            return nil
        }
        return place
    }

    func estimate(from origin: SchedulingPlace, to destination: SchedulingPlace, departing: Date) async -> TravelEstimate? {
        let key = "\(origin.latitude),\(origin.longitude)>\(destination.latitude),\(destination.longitude)"
        if let known = estimates[key] {
            return known
        }
        do {
            let estimate = try await estimator.estimate(from: origin, to: destination, mode: mode, departing: departing)
            estimates[key] = estimate
            return estimate
        } catch {
            note("Travel from '\(origin.label)' to '\(destination.label)' could not be estimated (\(error.localizedDescription)).")
            return nil
        }
    }

    func note(_ gap: String) {
        if !gaps.contains(gap) {
            gaps.append(gap)
        }
    }
}

public extension ScheduleTimeZone {
    func sameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    /// Minutes from local midnight of `day` to `date`; may exceed 1440 or be
    /// negative when `date` lies on another day.
    func minutes(of date: Date, since day: Date) -> Int {
        let midnight = calendar.startOfDay(for: day)
        return Int((date.timeIntervalSince(midnight) / 60).rounded())
    }
}

func wholeMinutes(_ seconds: TimeInterval) -> Int {
    Int((seconds / 60).rounded(.down))
}
