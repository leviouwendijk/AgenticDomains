import AgenticPrograms

public struct CreateReminderProgram:
    AgentProgram,
    Sendable
{
    public typealias Input = ReminderCreation
    public typealias Output = ReminderItem

    public static let descriptor = AgentProgramDescriptor(
        identifier: "apple_services.create_reminder",
        title: "Create Reminder",
        summary: "Create exactly one supplied reminder through the governed Apple Reminders mutation tool.",
        tags: [
            "apple_services",
            "reminders",
            "mutation",
            "approval",
        ]
    )

    public init() {}

    public func run(
        _ input: Input,
        in context: AgentProgramContext
    ) async throws -> Output {
        try await context.invoke(
            RemindersCreateTool.toolIdentifier,
            input: input,
            as: ReminderItem.self
        )
    }
}
