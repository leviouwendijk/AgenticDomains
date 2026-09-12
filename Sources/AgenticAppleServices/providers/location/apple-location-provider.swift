public protocol AppleLocationProvider: Sendable {
    func authorizationStatus() async
        -> LocationAuthorizationStatus

    func requestWhenInUseAuthorization() async
        -> LocationAuthorizationStatus

    func currentLocation() async throws
        -> AppleLocationSnapshot
}
