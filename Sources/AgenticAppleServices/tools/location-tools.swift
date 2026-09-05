import Agentic
import AgenticExecution
import Schema
import SchemaMacros

@JSONSchema
public struct AppleLocationEmptyToolInput:
    Codable,
    Sendable,
    Hashable
{
    public init() {}
}

public struct LocationAuthorizationStatusTool:
    AgentTool
{
    public typealias Input = AppleLocationEmptyToolInput
    public typealias Output = LocationAuthorizationStatus

    public let identifier: AgentToolIdentifier =
        "location_authorization_status"
    public let description =
        "Observe the current Core Location authorization status without requesting permission or reading location."
    public let risk: ActionRisk = .observe

    private let provider: any AppleLocationProvider

    public init(
        provider: any AppleLocationProvider
    ) {
        self.provider = provider
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        _ = input
        _ = context
        return await provider.authorizationStatus()
    }
}

public struct LocationRequestWhenInUseTool:
    AgentTool
{
    public typealias Input = AppleLocationEmptyToolInput
    public typealias Output = LocationAuthorizationStatus

    public let identifier: AgentToolIdentifier =
        "location_request_when_in_use"
    public let description =
        "Request when-in-use Core Location authorization through the macOS privacy permission flow."
    public let risk: ActionRisk = .boundedmutate

    private let provider: any AppleLocationProvider

    public init(
        provider: any AppleLocationProvider
    ) {
        self.provider = provider
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        _ = input
        _ = context
        return await provider
            .requestWhenInUseAuthorization()
    }
}

public struct LocationCurrentTool:
    AgentTool
{
    public typealias Input = AppleLocationEmptyToolInput
    public typealias Output = AppleLocationSnapshot

    public let identifier: AgentToolIdentifier =
        "location_current"
    public let description =
        "Read one current Core Location fix after location access has already been authorized."
    public let risk: ActionRisk = .observe

    private let provider: any AppleLocationProvider

    public init(
        provider: any AppleLocationProvider
    ) {
        self.provider = provider
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        _ = input
        _ = context
        return try await provider.currentLocation()
    }
}
