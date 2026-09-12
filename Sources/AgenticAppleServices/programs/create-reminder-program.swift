import AgenticPrograms
import Foundation

public enum CreateReminderProgramError:
    Error,
    Sendable,
    LocalizedError
{
    case remindersAuthorizationUnavailable(
        RemindersAuthorizationStatus
    )

    public var errorDescription: String? {
        switch self {
        case .remindersAuthorizationUnavailable(let status):
            return "Creating a reminder requires full Reminders access; authorization ended in \(status.rawValue)."
        }
    }
}

public struct CreateReminderProgram:
    AgentProgram,
    Sendable
{
    public typealias Input = ReminderCreation
    public typealias Output = ReminderItem

    public static let descriptor = AgentProgramDescriptor(
        identifier: "apple_services.create_reminder",
        title: "Create Reminder",
        summary: "Ensure full Reminders access through governed authorization tools, then create exactly one supplied reminder through the governed Apple Reminders mutation tool.",
        tags: [
            "apple_services",
            "reminders",
            "authorization",
            "mutation",
            "approval",
        ]
    )

    public init() {}

    public func run(
        _ input: Input,
        in context: AgentProgramContext
    ) async throws -> Output {
        let authorization = try await context.invoke(
            RemindersAuthorizationStatusTool.toolIdentifier,
            input: AppleRemindersEmptyToolInput(),
            as: RemindersAuthorizationStatus.self
        )

        switch authorization {
        case .full_access:
            break

        case .not_determined:
            let request = try await context.invoke(
                RemindersRequestFullAccessTool.toolIdentifier,
                input: AppleRemindersEmptyToolInput(),
                as: RemindersAuthorizationRequestResult.self
            )

            guard request.status == .full_access else {
                throw CreateReminderProgramError
                    .remindersAuthorizationUnavailable(
                        request.status
                    )
            }

        case .restricted, .denied, .unknown:
            throw CreateReminderProgramError
                .remindersAuthorizationUnavailable(
                    authorization
                )
        }

        return try await context.invoke(
            RemindersCreateTool.toolIdentifier,
            input: input,
            as: ReminderItem.self
        )
    }
}
