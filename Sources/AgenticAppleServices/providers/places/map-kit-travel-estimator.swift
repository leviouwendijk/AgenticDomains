import AgenticScheduling
import Apple
import Foundation

/// Travel times from Apple Maps routing. When routing fails (offline,
/// throttled, no route) it falls back to the straight-line estimate, and
/// the estimate's method says which one was used.
public actor MapKitTravelEstimator: TravelEstimator {
    private let directions: MapKitDirections
    private let fallback: any TravelEstimator
    private var known: [String: TravelEstimate] = [:]

    public init(
        directions: MapKitDirections = .init(),
        fallback: any TravelEstimator = StraightLineTravelEstimator()
    ) {
        self.directions = directions
        self.fallback = fallback
    }

    public func estimate(
        from origin: SchedulingPlace,
        to destination: SchedulingPlace,
        mode: TravelMode,
        departing: Date
    ) async throws -> TravelEstimate {
        guard origin.distanceKilometers(to: destination) >= StraightLineTravelEstimator.samePlaceKilometers else {
            return try await fallback.estimate(from: origin, to: destination, mode: mode, departing: departing)
        }
        // Traffic varies by hour, not by minute.
        let hour = Int(departing.timeIntervalSince1970 / 3600)
        let key = "\(origin.latitude),\(origin.longitude)>\(destination.latitude),\(destination.longitude)|\(mode.rawValue)|\(hour)"
        if let estimate = known[key] {
            return estimate
        }
        let estimate: TravelEstimate
        do {
            let route = try await directions.route(
                from: .init(latitude: origin.latitude, longitude: origin.longitude),
                to: .init(latitude: destination.latitude, longitude: destination.longitude),
                transport: Self.transport(mode),
                departing: departing
            )
            estimate = .init(
                minutes: Int((route.seconds / 60).rounded(.up)),
                mode: mode,
                method: .routed,
                distanceKilometers: (route.meters / 100).rounded() / 10
            )
        } catch {
            estimate = try await fallback.estimate(from: origin, to: destination, mode: mode, departing: departing)
        }
        known[key] = estimate
        return estimate
    }

    private static func transport(_ mode: TravelMode) -> MapsTransport {
        switch mode {
        case .driving:
            return .driving
        case .cycling:
            return .cycling
        case .walking:
            return .walking
        case .transit:
            return .transit
        }
    }
}
