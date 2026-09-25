import Agentic

public extension AppleServices.Programs {
    @Program
    struct PrepareDay {
        public typealias Input = PrepareDayInput
        public typealias Output = DayPlan

        public static let purpose =
            "Read bounded Calendar and Reminders facts, optionally read Weather for an explicit coordinate, prioritize the supplied facts semantically, and return a deterministic day plan."

        @InferenceSite
        public static var prioritization:
            Site<AppleServices.Inferences.PrioritizeDay>

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
            in context: ProgramContext
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
                Self.prioritization,
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
                recommendations: prioritization.recommendations,
                informationGaps: prioritization.informationGaps
            )
        }
    }
}
