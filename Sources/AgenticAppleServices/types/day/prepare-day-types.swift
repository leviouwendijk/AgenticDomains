import Schema
import SchemaMacros

public struct PrepareDayInput:
    Sendable,
    Codable,
    Hashable
{
    public let startDate: String
    public let endDate: String
    public let weatherCoordinate: WeatherCoordinate?
    public let context: String?

    public init(
        startDate: String,
        endDate: String,
        weatherCoordinate: WeatherCoordinate? = nil,
        context: String? = nil
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.weatherCoordinate = weatherCoordinate
        self.context = context
    }
}

@JSONSchema
public struct DayPriority:
    Sendable,
    Codable,
    Hashable
{
    public let title: String
    public let rationale: String

    public init(
        title: String,
        rationale: String
    ) {
        self.title = title
        self.rationale = rationale
    }
}

public struct DayPlan:
    Sendable,
    Codable,
    Hashable
{
    public let startDate: String
    public let endDate: String
    public let events: [CalendarEvent]
    public let reminders: [ReminderItem]
    public let weather: WeatherForecastSnapshot?
    public let priorities: [DayPriority]
    public let warnings: [String]
    public let suggestions: [String]

    public init(
        startDate: String,
        endDate: String,
        events: [CalendarEvent],
        reminders: [ReminderItem],
        weather: WeatherForecastSnapshot?,
        priorities: [DayPriority],
        warnings: [String],
        suggestions: [String]
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.events = events
        self.reminders = reminders
        self.weather = weather
        self.priorities = priorities
        self.warnings = warnings
        self.suggestions = suggestions
    }
}
