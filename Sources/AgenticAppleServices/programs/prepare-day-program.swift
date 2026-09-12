import AgenticPrograms

public struct PrepareDayProgram:
    AgentProgram,
    Sendable
{
    public typealias Input = PrepareDayInput
    public typealias Output = DayPlan

    public static let prioritizationSite: AgentInferenceSiteIdentifier =
        "prioritize_day"

    public static let descriptor = AgentProgramDescriptor(
        identifier: "apple_services.prepare_day",
        title: "Prepare Day",
        summary: "Read bounded Calendar and Reminders facts, optionally read Weather for an explicit coordinate, prioritize the supplied facts semantically, and return a deterministic day plan.",
        tags: [
            "apple_services",
            "calendar",
            "reminders",
            "weather",
            "planning",
            "inference",
        ]
    )

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

    public func run(
        _ input: Input,
        in context: AgentProgramContext
    ) async throws -> Output {
        let events = try await calendar.events(
            CalendarEventQuery(
                startDate: input.startDate,
                endDate: input.endDate,
                limit: 50
            )
        )

        let reminderItems = try await reminders.reminders(
            limit: 50
        )

        let forecast: WeatherForecastSnapshot?

        if let coordinate = input.weatherCoordinate {
            forecast = try await weather.forecast(
                at: coordinate,
                hours: 24,
                days: 2
            )
        } else {
            forecast = nil
        }

        let prioritization = try await context.infer(
            PrioritizeDay.self,
            at: Self.prioritizationSite,
            input: PrioritizeDayInput(
                startDate: input.startDate,
                endDate: input.endDate,
                events: events,
                reminders: reminderItems,
                weather: forecast,
                context: input.context
            )
        )

        return DayPlan(
            startDate: input.startDate,
            endDate: input.endDate,
            events: events,
            reminders: reminderItems,
            weather: forecast,
            priorities: prioritization.priorities,
            warnings: prioritization.warnings,
            suggestions: prioritization.suggestions
        )
    }
}
