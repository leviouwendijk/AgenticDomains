import AgenticRecovery
import Agentic
import AgenticExecution
import Schema
import Macros

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

    public static let toolIdentifier: AgentToolIdentifier =
        "reminders_authorization_status"

    public let identifier: AgentToolIdentifier =
        Self.toolIdentifier
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

    public static let toolIdentifier: AgentToolIdentifier =
        "reminders_request_full_access"

    public let identifier: AgentToolIdentifier =
        Self.toolIdentifier
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

public struct RemindersCreateTool:
    AgentTool
{
    public typealias Input = ReminderCreation
    public typealias Output = ReminderItem

    public static let toolIdentifier:
        AgentToolIdentifier = "reminders_create"

    public let identifier: AgentToolIdentifier =
        Self.toolIdentifier
    public let description =
        "Create exactly one reminder in an explicit reminder list or the configured default reminders list."
    public let risk: ActionRisk = .boundedmutate

    private let provider: any AppleRemindersProvider

    public init(
        provider: any AppleRemindersProvider
    ) {
        self.provider = provider
    }

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let destination =
            input.listTitle ?? "default reminders list"

        return ToolPreflight(
            toolName: identifier.rawValue,
            risk: risk,
            workspaceRoot: context.workspace?.rootURL.path,
            summary: "Create reminder '\(input.title)' in \(destination)."
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        _ = context

        return try await provider.createReminder(
            input
        )
    }

    public func classify(
        _ error: any Error,
        phase: AgentToolCallPhase,
        input _: Input?,
        context: AgentToolExecutionContext
    ) -> Recovery.Incident? {
        guard
            phase == .call,
            let error = error
                as? RemindersAuthorizationRequiredError
        else {
            return nil
        }

        return Recovery.Incident(
            kind: .authorization_required,
            stage: .execution,
            effectState: .not_applied,
            retrySafety: .safe,
            scope: .init(
                kind: .tool,
                identifier:
                    context.toolCallID
                    ?? identifier.rawValue
            ),
            message: error.localizedDescription
        )
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
