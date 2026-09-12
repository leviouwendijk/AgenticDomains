import Agentic
import AgenticExecution
import Schema
import SchemaMacros

@JSONSchema
public struct CalendarEventsToolInput:
    Codable,
    Sendable,
    Hashable
{
    /// Inclusive query start as an ISO 8601 timestamp.
    public let startDate: String

    /// Exclusive query end as an ISO 8601 timestamp.
    public let endDate: String

    /// Maximum number of events to return. The provider clamps this to 1...200.
    public let limit: Int

    public init(
        startDate: String,
        endDate: String,
        limit: Int
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.limit = limit
    }
}

public struct CalendarEventsTool:
    AgentTool
{
    public typealias Input = CalendarEventsToolInput
    public typealias Output = [CalendarEvent]

    public let identifier: AgentToolIdentifier =
        "calendar_events"
    public let description =
        "Read calendar events in an explicit ISO 8601 time range using the configured Apple Calendar provider."
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
        _ = context

        return try await provider.events(
            .init(
                startDate: input.startDate,
                endDate: input.endDate,
                limit: input.limit
            )
        )
    }
}
