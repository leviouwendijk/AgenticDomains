import Agentic

public struct AppleServicesProgramSet:
    ProgramSet,
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
            AppleServices.Programs.PrepareDay(
                calendar: calendar,
                reminders: reminders,
                weather: weather
            )
        )

        try registry.register(
            AppleServices.Programs.CreateReminder()
        )
    }
}
