import AgenticInference
import Schema
import Macros

public struct PrioritizeDayInput:
    Sendable,
    Codable,
    Hashable
{
    public let startDate: String
    public let endDate: String
    public let events: [CalendarEvent]
    public let reminders: [ReminderItem]
    public let weather: WeatherForecastSnapshot?
    public let context: String?

    public init(
        startDate: String,
        endDate: String,
        events: [CalendarEvent],
        reminders: [ReminderItem],
        weather: WeatherForecastSnapshot?,
        context: String?
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.events = events
        self.reminders = reminders
        self.weather = weather
        self.context = context
    }
}

@JSONSchema
public struct PrioritizeDayOutput:
    Sendable,
    Codable,
    Hashable
{
    public let priorities: [DayPriority]
    public let warnings: [DayWarning]
    public let recommendations: [DayRecommendation]
    public let informationGaps: [DayInformationGap]

    public init(
        priorities: [DayPriority],
        warnings: [DayWarning],
        recommendations: [DayRecommendation],
        informationGaps: [DayInformationGap]
    ) {
        self.priorities = priorities
        self.warnings = warnings
        self.recommendations = recommendations
        self.informationGaps = informationGaps
    }
}

public struct PrioritizeDay:
    AgentInference,
    Sendable
{
    public typealias Input = PrioritizeDayInput
    public typealias Output = PrioritizeDayOutput

    public static let definition = AgentInferenceDefinition(
        identifier: "apple_services.prioritize_day",
        purpose: "Prioritize a bounded day from supplied calendar events, reminders, optional weather, and user context. Return explicit priorities, warnings, recommendations, and information gaps without inventing additional source facts."
    )

    public init() {}
}
