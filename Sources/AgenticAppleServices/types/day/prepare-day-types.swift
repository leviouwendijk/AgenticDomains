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
    public let warnings: [DayWarning]
    public let recommendations: [DayRecommendation]
    public let informationGaps: [DayInformationGap]

    public init(
        startDate: String,
        endDate: String,
        events: [CalendarEvent],
        reminders: [ReminderItem],
        weather: WeatherForecastSnapshot?,
        priorities: [DayPriority],
        warnings: [DayWarning],
        recommendations: [DayRecommendation],
        informationGaps: [DayInformationGap]
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.events = events
        self.reminders = reminders
        self.weather = weather
        self.priorities = priorities
        self.warnings = warnings
        self.recommendations = recommendations
        self.informationGaps = informationGaps
    }
}
