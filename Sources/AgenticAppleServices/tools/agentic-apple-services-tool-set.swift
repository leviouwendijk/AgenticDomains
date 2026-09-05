import AgenticExecution

public struct AgenticAppleServicesToolSet:
    AgentToolSet
{
    public let calendar: any AppleCalendarProvider
    public let reminders: any AppleRemindersProvider
    public let weather: any AppleWeatherProvider
    public let location: any AppleLocationProvider

    public init(
        calendar: any AppleCalendarProvider =
            EventKitCalendarProvider(),
        reminders: any AppleRemindersProvider =
            EventKitRemindersProvider(),
        weather: any AppleWeatherProvider =
            WeatherKitWeatherProvider(),
        location: any AppleLocationProvider =
            CoreLocationProvider()
    ) {
        self.calendar = calendar
        self.reminders = reminders
        self.weather = weather
        self.location = location
    }

    public func register(
        into registry: inout ToolRegistry
    ) throws {
        try registry.register {
            CalendarAuthorizationStatusTool(
                provider: calendar
            )
            CalendarRequestFullAccessTool(
                provider: calendar
            )
            CalendarEventsTool(
                provider: calendar
            )

            RemindersAuthorizationStatusTool(
                provider: reminders
            )
            RemindersRequestFullAccessTool(
                provider: reminders
            )
            RemindersTool(
                provider: reminders
            )

            WeatherCurrentTool(
                provider: weather
            )
            WeatherForecastTool(
                provider: weather
            )

            LocationAuthorizationStatusTool(
                provider: location
            )
            LocationRequestWhenInUseTool(
                provider: location
            )
            LocationCurrentTool(
                provider: location
            )
        }
    }
}
