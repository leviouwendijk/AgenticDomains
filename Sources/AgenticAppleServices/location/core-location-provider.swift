@preconcurrency import CoreLocation
import Foundation

public actor CoreLocationProvider:
    AppleLocationProvider
{
    private var authorizationBridge:
        CoreLocationAuthorizationBridge?
    private var locationBridge:
        CoreLocationRequestBridge?

    public init() {}

    public func authorizationStatus() async
        -> LocationAuthorizationStatus
    {
        await MainActor.run {
            let manager = CLLocationManager()
            return appleLocationAuthorizationStatus(
                manager.authorizationStatus
            )
        }
    }

    public func requestWhenInUseAuthorization() async
        -> LocationAuthorizationStatus
    {
        let bridge = await MainActor.run {
            CoreLocationAuthorizationBridge()
        }
        authorizationBridge = bridge

        let status = await bridge.request()
        authorizationBridge = nil
        return status
    }

    public func currentLocation() async throws
        -> AppleLocationSnapshot
    {
        let status = await authorizationStatus()

        guard status == .whenInUse
                || status == .always
        else {
            throw CoreLocationProviderError
                .authorizationRequired(status)
        }

        let bridge = await MainActor.run {
            CoreLocationRequestBridge()
        }
        locationBridge = bridge

        do {
            let result = try await bridge.request()
            locationBridge = nil
            return result
        } catch {
            locationBridge = nil
            throw error
        }
    }
}

private func appleLocationAuthorizationStatus(
    _ status: CLAuthorizationStatus
) -> LocationAuthorizationStatus {
    switch status {
    case .notDetermined:
        return .notDetermined
    case .restricted:
        return .restricted
    case .denied:
        return .denied
    case .authorizedWhenInUse:
        return .whenInUse
    case .authorizedAlways:
        return .always
    @unknown default:
        return .unknown
    }
}

@MainActor
private final class CoreLocationAuthorizationBridge:
    NSObject,
    CLLocationManagerDelegate,
    @unchecked Sendable
{
    private let manager: CLLocationManager
    private var continuation:
        CheckedContinuation<
            LocationAuthorizationStatus,
            Never
        >?

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
    }

    func request() async
        -> LocationAuthorizationStatus
    {
        let current = appleLocationAuthorizationStatus(
            manager.authorizationStatus
        )

        guard current == .notDetermined else {
            return current
        }

        return await withCheckedContinuation {
            continuation in

            self.continuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        let status = appleLocationAuthorizationStatus(
            manager.authorizationStatus
        )

        guard status != .notDetermined else {
            return
        }

        Task { @MainActor [weak self] in
            guard let self,
                  let continuation = self.continuation
            else {
                return
            }

            self.continuation = nil
            continuation.resume(
                returning: status
            )
        }
    }
}

@MainActor
private final class CoreLocationRequestBridge:
    NSObject,
    CLLocationManagerDelegate,
    @unchecked Sendable
{
    private let manager: CLLocationManager
    private var continuation:
        CheckedContinuation<
            AppleLocationSnapshot,
            any Error
        >?

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy =
            kCLLocationAccuracyHundredMeters
    }

    func request() async throws
        -> AppleLocationSnapshot
    {
        try await withCheckedThrowingContinuation {
            continuation in

            self.continuation = continuation
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else {
            return
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions.insert(
            .withFractionalSeconds
        )

        let snapshot = AppleLocationSnapshot(
            latitude:
                location.coordinate.latitude,
            longitude:
                location.coordinate.longitude,
            horizontalAccuracyMeters:
                location.horizontalAccuracy,
            altitudeMeters:
                location.altitude,
            timestamp:
                formatter.string(
                    from: location.timestamp
                )
        )

        Task { @MainActor [weak self] in
            guard let self,
                  let continuation = self.continuation
            else {
                return
            }

            self.continuation = nil
            continuation.resume(
                returning: snapshot
            )
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: any Error
    ) {
        let failure = CoreLocationProviderError
            .locationRequestFailed(
                error.localizedDescription
            )

        Task { @MainActor [weak self] in
            guard let self,
                  let continuation = self.continuation
            else {
                return
            }

            self.continuation = nil
            continuation.resume(
                throwing: failure
            )
        }
    }
}

public enum CoreLocationProviderError:
    Error,
    Sendable,
    LocalizedError
{
    case authorizationRequired(
        LocationAuthorizationStatus
    )
    case locationRequestFailed(String)

    public var errorDescription: String? {
        switch self {
        case .authorizationRequired(let status):
            return "Current location requires an authorized Core Location state; current status is \(status.rawValue)."

        case .locationRequestFailed(let description):
            return "Core Location request failed: \(description)"
        }
    }
}
