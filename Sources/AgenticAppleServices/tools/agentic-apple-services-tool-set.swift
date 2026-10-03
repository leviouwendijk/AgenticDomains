import Agentic

public struct AppleServicesToolProvider:
    AgentToolProvider
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
            WeatherKitRESTProvider(),
        location: any AppleLocationProvider =
            CoreLocationProvider()
    ) {
        self.calendar = calendar
        self.reminders = reminders
        self.weather = weather
        self.location = location
    }

    public func registerTools(
        into registry: inout ToolRegistry
    ) throws {
        try registry.register(
            AppleServices.Tools.ReadCalendarAuthorizationStatus(
                provider: calendar
            )
        )
        try registry.register(
            AppleServices.Tools.RequestCalendarFullAccess(
                provider: calendar
            )
        )
        try registry.register(
            AppleServices.Tools.ReadCalendarEvents(
                provider: calendar
            )
        )

        try registry.register(
            AppleServices.Tools.ReadRemindersAuthorizationStatus(
                provider: reminders
            )
        )
        try registry.register(
            AppleServices.Tools.RequestRemindersFullAccess(
                provider: reminders
            )
        )
        try registry.register(
            AppleServices.Tools.ReadReminders(
                provider: reminders
            )
        )
        try registry.register(
            AppleServices.Tools.CreateReminder(
                provider: reminders
            )
        )

        try registry.register(
            AppleServices.Tools.ReadCurrentWeather(
                provider: weather
            )
        )
        try registry.register(
            AppleServices.Tools.ReadWeatherForecast(
                provider: weather
            )
        )

        try registry.register(
            AppleServices.Tools.ReadLocationAuthorizationStatus(
                provider: location
            )
        )
        try registry.register(
            AppleServices.Tools.RequestLocationWhenInUse(
                provider: location
            )
        )
        try registry.register(
            AppleServices.Tools.ReadCurrentLocation(
                provider: location
            )
        )
    }
}
