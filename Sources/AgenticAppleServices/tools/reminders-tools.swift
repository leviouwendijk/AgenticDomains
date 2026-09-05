import Agentic
import AgenticExecution
import Schema
import SchemaMacros

@JSONSchema
public struct AppleRemindersEmptyToolInput:
    Codable,
    Sendable,
    Hashable
{
    public init() {}
}

@JSONSchema
public struct RemindersToolInput:
    Codable,
    Sendable,
    Hashable
{
    /// Maximum number of reminders to return. The provider clamps this to 1...200.
    public let limit: Int

    public init(
        limit: Int
    ) {
        self.limit = limit
    }
}

public struct RemindersAuthorizationStatusTool:
    AgentTool
{
    public typealias Input = AppleRemindersEmptyToolInput
    public typealias Output = RemindersAuthorizationStatus

    public let identifier: AgentToolIdentifier =
        "reminders_authorization_status"
    public let description =
        "Observe the current macOS Reminders authorization status without requesting permission."
    public let risk: ActionRisk = .observe

    private let provider: any AppleRemindersProvider

    public init(
        provider: any AppleRemindersProvider
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

public struct RemindersRequestFullAccessTool:
    AgentTool
{
    public typealias Input = AppleRemindersEmptyToolInput
    public typealias Output = RemindersAuthorizationRequestResult

    public let identifier: AgentToolIdentifier =
        "reminders_request_full_access"
    public let description =
        "Request full access to the user's reminders through the macOS EventKit privacy permission flow."
    public let risk: ActionRisk = .boundedmutate

    private let provider: any AppleRemindersProvider

    public init(
        provider: any AppleRemindersProvider
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

public struct RemindersTool:
    AgentTool
{
    public typealias Input = RemindersToolInput
    public typealias Output = [ReminderItem]

    public let identifier: AgentToolIdentifier =
        "reminders"
    public let description =
        "Read reminders using the configured Apple Reminders provider."
    public let risk: ActionRisk = .observe

    private let provider: any AppleRemindersProvider

    public init(
        provider: any AppleRemindersProvider
    ) {
        self.provider = provider
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        _ = context
        return try await provider.reminders(
            limit: input.limit
        )
    }
}
