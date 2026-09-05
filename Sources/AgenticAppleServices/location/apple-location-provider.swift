public enum LocationAuthorizationStatus:
    String,
    Sendable,
    Codable,
    Hashable
{
    case notDetermined = "not_determined"
    case restricted
    case denied
    case whenInUse = "when_in_use"
    case always
    case unknown
}

public struct AppleLocationSnapshot:
    Sendable,
    Codable,
    Hashable
{
    public let latitude: Double
    public let longitude: Double
    public let horizontalAccuracyMeters: Double
    public let altitudeMeters: Double
    public let timestamp: String

    public init(
        latitude: Double,
        longitude: Double,
        horizontalAccuracyMeters: Double,
        altitudeMeters: Double,
        timestamp: String
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.altitudeMeters = altitudeMeters
        self.timestamp = timestamp
    }
}

public protocol AppleLocationProvider: Sendable {
    func authorizationStatus() async
        -> LocationAuthorizationStatus

    func requestWhenInUseAuthorization() async
        -> LocationAuthorizationStatus

    func currentLocation() async throws
        -> AppleLocationSnapshot
}
