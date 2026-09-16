import Agentic
import AgenticRecovery
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
    case remindersAuthorizationRequestDeclined

    public var errorDescription: String? {
        switch self {
        case .remindersAuthorizationUnavailable(let status):
            return "Creating a reminder requires full Reminders access; authorization ended in \(status.rawValue)."

        case .remindersAuthorizationRequestDeclined:
            return "Creating the reminder was stopped because requesting Reminders access was declined."
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
        try await ensureFullAccess(
            in: context
        )

        return try await createWithAuthorizationRecovery(
            input,
            in: context
        )
    }

    private func ensureFullAccess(
        in context: AgentProgramContext
    ) async throws {
        let authorization = try await context.invoke(
            RemindersAuthorizationStatusTool.toolIdentifier,
            input: AppleRemindersEmptyToolInput(),
            as: RemindersAuthorizationStatus.self
        )

        switch authorization {
        case .full_access:
            return

        case .not_determined:
            let response = try await context.ask(
                UserInputRequest(
                    prompt: "Allow Agentic to request Reminders access from macOS?",
                    reason: "Creating this reminder requires full Reminders access. Continuing will ask macOS to display its system permission prompt.",
                    input: .confirmation(
                        ConfirmationUserInput(
                            defaultValue: false,
                            confirmLabel: "Request access",
                            cancelLabel: "Do not request"
                        )
                    ),
                    presentation: UserInputPresentation(
                        title: "Reminders access",
                        preferredControl: .confirmation
                    ),
                    metadata: [
                        "domain": "apple_services",
                        "capability": "reminders",
                        "operation": "request_full_access",
                    ]
                )
            )

            guard case .answered(.confirmation(true)) = response.outcome else {
                throw CreateReminderProgramError
                    .remindersAuthorizationRequestDeclined
            }

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
    }

    private func createWithAuthorizationRecovery(
        _ input: Input,
        in context: AgentProgramContext
    ) async throws -> Output {
        try await context.invoke(
            RemindersCreateTool.toolIdentifier,
            input: input,
            as: ReminderItem.self
        ) { failure -> Output in
            guard
                failure.recovery?.incident.kind
                    == .authorization_required,
                failure.effect == .not_applied,
                failure.retry == .safe,
                failure.outcome == .propagated
            else {
                throw failure
            }

            try await ensureFullAccess(
                in: context
            )

            return try await context.invoke(
                RemindersCreateTool.toolIdentifier,
                input: input,
                as: ReminderItem.self
            )
        }
    }
}
