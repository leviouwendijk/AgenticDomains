public enum LocationAuthorizationStatus:
    String,
    Sendable,
    Codable,
    Hashable
{
    case not_determined
    case restricted
    case denied
    case when_in_use
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
