import Foundation
import Macros
import Schema

/// A resolved location.
@JSONSchema
public struct SchedulingPlace:
    Sendable,
    Codable,
    Hashable
{
    public let label: String
    public let latitude: Double
    public let longitude: Double

    public init(label: String, latitude: Double, longitude: Double) {
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Great-circle distance in kilometres.
    public func distanceKilometers(to other: SchedulingPlace) -> Double {
        let radius = 6371.0
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLat = (other.latitude - latitude) * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * radius * atan2(sqrt(a), sqrt(1 - a))
    }
}

@JSONSchema
public enum TravelMode:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case driving
    case cycling
    case walking
    case transit
}

/// How a travel time was obtained.
@JSONSchema
public enum TravelEstimateMethod:
    String,
    Sendable,
    Codable,
    Hashable
{
    /// Distance as the crow flies with a detour factor and fixed overhead.
    case straight_line
    /// A routing service's estimate.
    case routed
    /// Both ends resolve to the same place.
    case same_place
}

@JSONSchema
public struct TravelEstimate:
    Sendable,
    Codable,
    Hashable
{
    public let minutes: Int
    public let mode: TravelMode
    public let method: TravelEstimateMethod
    public let distanceKilometers: Double?

    public init(
        minutes: Int,
        mode: TravelMode,
        method: TravelEstimateMethod,
        distanceKilometers: Double?
    ) {
        self.minutes = minutes
        self.mode = mode
        self.method = method
        self.distanceKilometers = distanceKilometers
    }
}
