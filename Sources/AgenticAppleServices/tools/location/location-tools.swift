import Agentic
import Macros
import Schema
import Workspace

public extension AppleServices.Tools {
    @Tool("location_authorization_status")
    struct ReadLocationAuthorizationStatus {
        @JSONSchema
        public struct Input:
            Codable,
            Sendable,
            Hashable
        {
            public init() {}
        }

        public typealias Output = LocationAuthorizationStatus

        public static let purpose =
            "Observe the current Core Location authorization status without requesting permission or reading location."
        public static let risk: ActionRisk = .observe

        private let provider: any AppleLocationProvider

        public init(
            provider: any AppleLocationProvider
        ) {
            self.provider = provider
        }

        public func call(
            _ input: Input,
            workspace _: WorkspaceContext?
        ) async throws -> Output {
            _ = input
            return await provider.authorizationStatus()
        }
    }

    @Tool("location_request_when_in_use")
    struct RequestLocationWhenInUse {
        @JSONSchema
        public struct Input:
            Codable,
            Sendable,
            Hashable
        {
            public init() {}
        }

        public typealias Output = LocationAuthorizationStatus

        public static let purpose =
            "Request when-in-use Core Location authorization through the macOS privacy permission flow."
        public static let risk: ActionRisk = .boundedmutate

        private let provider: any AppleLocationProvider

        public init(
            provider: any AppleLocationProvider
        ) {
            self.provider = provider
        }

        public func call(
            _ input: Input,
            workspace _: WorkspaceContext?
        ) async throws -> Output {
            _ = input
            return await provider
                .requestWhenInUseAuthorization()
        }
    }

    @Tool("location_current")
    struct ReadCurrentLocation {
        @JSONSchema
        public struct Input:
            Codable,
            Sendable,
            Hashable
        {
            public init() {}
        }

        public typealias Output = AppleLocationSnapshot

        public static let purpose =
            "Read one current Core Location fix after location access has already been authorized."
        public static let risk: ActionRisk = .observe

        private let provider: any AppleLocationProvider

        public init(
            provider: any AppleLocationProvider
        ) {
            self.provider = provider
        }

        public func call(
            _ input: Input,
            workspace _: WorkspaceContext?
        ) async throws -> Output {
            _ = input
            return try await provider.currentLocation()
        }
    }
}
