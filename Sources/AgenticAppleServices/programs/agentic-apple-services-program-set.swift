import AgenticPrograms

public struct AgenticAppleServicesProgramSet:
    AgentProgramSet,
    Sendable
{
    private let calendar: any AppleCalendarProvider
    private let reminders: any AppleRemindersProvider
    private let weather: any AppleWeatherProvider

    public init(
        calendar: any AppleCalendarProvider =
            EventKitCalendarProvider(),
        reminders: any AppleRemindersProvider =
            EventKitRemindersProvider(),
        weather: any AppleWeatherProvider =
            WeatherKitRESTProvider()
    ) {
        self.calendar = calendar
        self.reminders = reminders
        self.weather = weather
    }

    public func register(
        into registry: inout ProgramRegistry
    ) throws {
        try registry.register(
            PrepareDayProgram(
                calendar: calendar,
                reminders: reminders,
                weather: weather
            )
        )
        try registry.register(
            CreateReminderProgram()
        )
    }
}
