import AgenticScheduling
import CoreLocation
import Foundation
import MapKit

/// Travel times from Apple Maps routing. When routing fails (offline,
/// throttled, no route) it falls back to the straight-line estimate, and
/// the estimate's method says which one was used.
public actor MapKitTravelEstimator: TravelEstimator {
    private let fallback: any TravelEstimator
    private var known: [String: TravelEstimate] = [:]

    public init(fallback: any TravelEstimator = StraightLineTravelEstimator()) {
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
            let route = try await Self.route(from: origin, to: destination, mode: mode, departing: departing)
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

    @MainActor
    private static func route(
        from origin: SchedulingPlace,
        to destination: SchedulingPlace,
        mode: TravelMode,
        departing: Date
    ) async throws -> (seconds: TimeInterval, meters: CLLocationDistance) {
        let request = MKDirections.Request()
        request.source = item(origin)
        request.destination = item(destination)
        request.transportType = transport(mode)
        request.departureDate = departing
        let response = try await MKDirections(request: request).calculateETA()
        return (response.expectedTravelTime, response.distance)
    }

    @MainActor
    private static func item(_ place: SchedulingPlace) -> MKMapItem {
        if #available(macOS 26.0, *) {
            return MKMapItem(
                location: CLLocation(latitude: place.latitude, longitude: place.longitude),
                address: nil
            )
        }
        return MKMapItem(
            placemark: MKPlacemark(
                coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
            )
        )
    }

    private static func transport(_ mode: TravelMode) -> MKDirectionsTransportType {
        switch mode {
        case .driving:
            return .automobile
        case .cycling:
            return .cycling
        case .walking:
            return .walking
        case .transit:
            return .transit
        }
    }
}
