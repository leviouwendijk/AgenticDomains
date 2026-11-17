import Foundation

public protocol TravelEstimator: Sendable {
    func estimate(
        from origin: SchedulingPlace,
        to destination: SchedulingPlace,
        mode: TravelMode,
        departing: Date
    ) async throws -> TravelEstimate
}

/// Offline estimate: great-circle distance times a detour factor, at a
/// typical door-to-door speed per mode, plus fixed overhead (parking,
/// walking to a stop). Errs long rather than short.
public struct StraightLineTravelEstimator: TravelEstimator {
    public struct Profile: Sendable, Hashable {
        public let kilometersPerHour: Double
        public let detourFactor: Double
        public let overheadMinutes: Int

        public init(kilometersPerHour: Double, detourFactor: Double, overheadMinutes: Int) {
            self.kilometersPerHour = kilometersPerHour
            self.detourFactor = detourFactor
            self.overheadMinutes = overheadMinutes
        }
    }

    /// Below this distance both ends count as the same place.
    public static let samePlaceKilometers = 0.2

    private let profiles: [TravelMode: Profile]

    public init(profiles: [TravelMode: Profile] = Self.defaultProfiles) {
        self.profiles = profiles
    }

    public static let defaultProfiles: [TravelMode: Profile] = [
        .driving: .init(kilometersPerHour: 50, detourFactor: 1.3, overheadMinutes: 10),
        .cycling: .init(kilometersPerHour: 15, detourFactor: 1.25, overheadMinutes: 5),
        .walking: .init(kilometersPerHour: 4.8, detourFactor: 1.25, overheadMinutes: 0),
        .transit: .init(kilometersPerHour: 25, detourFactor: 1.4, overheadMinutes: 15),
    ]

    private static let fallbackProfile = Profile(kilometersPerHour: 50, detourFactor: 1.3, overheadMinutes: 10)

    public func estimate(
        from origin: SchedulingPlace,
        to destination: SchedulingPlace,
        mode: TravelMode,
        departing _: Date
    ) async throws -> TravelEstimate {
        let distance = origin.distanceKilometers(to: destination)
        guard distance >= Self.samePlaceKilometers else {
            return .init(minutes: 0, mode: mode, method: .same_place, distanceKilometers: distance)
        }
        let profile = profiles[mode] ?? Self.fallbackProfile
        let moving = distance * profile.detourFactor / profile.kilometersPerHour * 60
        return .init(
            minutes: Int(moving.rounded(.up)) + profile.overheadMinutes,
            mode: mode,
            method: .straight_line,
            distanceKilometers: (distance * 10).rounded() / 10
        )
    }
}
