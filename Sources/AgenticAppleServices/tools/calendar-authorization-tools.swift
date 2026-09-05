import Agentic
import AgenticExecution
import Schema
import SchemaMacros

@JSONSchema
public struct AppleCalendarEmptyToolInput:
    Codable,
    Sendable,
    Hashable
{
    public init() {}
}

public struct CalendarAuthorizationStatusTool:
    AgentTool
{
    public typealias Input = AppleCalendarEmptyToolInput
    public typealias Output = CalendarAuthorizationStatus

    public let identifier: AgentToolIdentifier =
        "calendar_authorization_status"
    public let description =
        "Observe the current macOS Calendar authorization status without requesting permission."
    public let risk: ActionRisk = .observe

    private let provider: any AppleCalendarProvider

    public init(
        provider: any AppleCalendarProvider
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

public struct CalendarRequestFullAccessTool:
    AgentTool
{
    public typealias Input = AppleCalendarEmptyToolInput
    public typealias Output = CalendarAuthorizationRequestResult

    public let identifier: AgentToolIdentifier =
        "calendar_request_full_access"
    public let description =
        "Request full access to the user's calendars through the macOS EventKit privacy permission flow."
    public let risk: ActionRisk = .boundedmutate

    private let provider: any AppleCalendarProvider

    public init(
        provider: any AppleCalendarProvider
    ) {
        self.provider = provider
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        _ = input
        _ = context
        return try await provider.requestFullAccess()
    }
}
