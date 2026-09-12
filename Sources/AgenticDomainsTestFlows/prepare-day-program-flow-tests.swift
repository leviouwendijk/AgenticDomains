import AgenticAppleServices
import AgenticInference
import AgenticPrograms
import Foundation
import TestFlows

private enum PrepareDayFixtureError: Error {
    case unexpectedInference(String)
    case unexpectedInferenceSite(String)
    case unexpectedWeatherCurrentCall
    case unexpectedReminderCreation
}

private actor PrepareDayCalendarFixture:
    AppleCalendarProvider
{
    private var receivedQueries: [CalendarEventQuery] = []

    func authorizationStatus() async
        -> CalendarAuthorizationStatus
    {
        .full_access
    }

    func requestFullAccess() async throws
        -> CalendarAuthorizationRequestResult
    {
        .init(
            granted: true,
            status: .full_access
        )
    }

    func events(
        _ query: CalendarEventQuery
    ) async throws -> [CalendarEvent] {
        receivedQueries.append(query)

        return [
            CalendarEvent(
                identifier: "event.design_review",
                title: "Design review",
                startDate: "2026-09-12T09:00:00Z",
                endDate: "2026-09-12T10:00:00Z",
                isAllDay: false,
                calendarTitle: "Work",
                location: nil,
                notes: "Review the Program architecture."
            ),
        ]
    }

    func queries() -> [CalendarEventQuery] {
        receivedQueries
    }
}

private actor PrepareDayRemindersFixture:
    AppleRemindersProvider
{
    private var receivedLimits: [Int] = []

    func authorizationStatus() async
        -> RemindersAuthorizationStatus
    {
        .full_access
    }

    func requestFullAccess() async throws
        -> RemindersAuthorizationRequestResult
    {
        .init(
            granted: true,
            status: .full_access
        )
    }

    func reminders(
        limit: Int
    ) async throws -> [ReminderItem] {
        receivedLimits.append(limit)

        return [
            ReminderItem(
                identifier: "reminder.expenses",
                title: "File expenses",
                isCompleted: false,
                dueDate: "2026-09-12T16:00:00Z",
                completionDate: nil,
                calendarTitle: "Tasks",
                notes: nil,
                priority: 1
            ),
        ]
    }

    func createReminder(
        _ creation: ReminderCreation
    ) async throws -> ReminderItem {
        _ = creation
        throw PrepareDayFixtureError
            .unexpectedReminderCreation
    }

    func limits() -> [Int] {
        receivedLimits
    }
}

private struct PrepareDayWeatherForecastCall:
    Sendable,
    Equatable
{
    let coordinate: WeatherCoordinate
    let hours: Int
    let days: Int
}

private actor PrepareDayWeatherFixture:
    AppleWeatherProvider
{
    private var forecastCalls: [PrepareDayWeatherForecastCall] = []

    func currentWeather(
        at _: WeatherCoordinate
    ) async throws -> CurrentWeatherSnapshot {
        throw PrepareDayFixtureError.unexpectedWeatherCurrentCall
    }

    func forecast(
        at coordinate: WeatherCoordinate,
        hours: Int,
        days: Int
    ) async throws -> WeatherForecastSnapshot {
        forecastCalls.append(
            .init(
                coordinate: coordinate,
                hours: hours,
                days: days
            )
        )

        return WeatherForecastSnapshot(
            coordinate: coordinate,
            hourly: [
                HourlyWeatherSnapshot(
                    date: "2026-09-12T09:00:00Z",
                    conditionCode: "rain",
                    symbolName: nil,
                    temperatureCelsius: 16,
                    precipitationChance: 0.8
                ),
            ],
            daily: [
                DailyWeatherSnapshot(
                    date: "2026-09-12T00:00:00Z",
                    conditionCode: "rain",
                    symbolName: nil,
                    lowTemperatureCelsius: 12,
                    highTemperatureCelsius: 18,
                    precipitationChance: 0.8
                ),
            ]
        )
    }

    func calls() -> [PrepareDayWeatherForecastCall] {
        forecastCalls
    }
}

private actor PrepareDayInferenceFixture:
    AgentInferenceInvoking
{
    private var receivedInputs: [PrioritizeDayInput] = []

    func infer<Inference: AgentInference>(
        _ inference: Inference.Type,
        at site: AgentInferenceSiteIdentifier,
        input: Inference.Input
    ) async throws -> Inference.Output {
        guard inference.definition.identifier
            == PrioritizeDay.definition.identifier
        else {
            throw PrepareDayFixtureError.unexpectedInference(
                inference.definition.identifier.rawValue
            )
        }

        guard site == PrepareDayProgram.prioritizationSite else {
            throw PrepareDayFixtureError.unexpectedInferenceSite(
                site.rawValue
            )
        }

        let encodedInput = try JSONEncoder().encode(input)
        let dayInput = try JSONDecoder().decode(
            PrioritizeDayInput.self,
            from: encodedInput
        )

        receivedInputs.append(dayInput)

        let priorities: [DayPriority]

        if let firstEvent = dayInput.events.first {
            priorities = [
                DayPriority(
                    title: firstEvent.title,
                    rationale: "Protect the scheduled commitment before flexible work."
                ),
            ]
        } else if let firstReminder = dayInput.reminders.first {
            priorities = [
                DayPriority(
                    title: firstReminder.title,
                    rationale: "Address the highest-signal supplied reminder."
                ),
            ]
        } else {
            priorities = []
        }

        let warnings: [DayWarning]

        if let weather = dayInput.weather,
           let firstDay = weather.daily.first,
           firstDay.precipitationChance >= 0.5
        {
            warnings = [
                DayWarning(
                    summary: "Meaningful precipitation risk",
                    rationale: "The supplied daily forecast reports a precipitation chance of \(firstDay.precipitationChance)."
                ),
            ]
        } else {
            warnings = []
        }

        let recommendations = dayInput.context.map {
            [
                DayRecommendation(
                    action: "Respect the supplied day context",
                    rationale: $0
                ),
            ]
        } ?? []

        let informationGaps: [DayInformationGap]

        if dayInput.weather == nil {
            informationGaps = [
                DayInformationGap(
                    subject: "weather",
                    reason: "No weather coordinate was supplied, so weather was not read."
                ),
            ]
        } else {
            informationGaps = []
        }

        let output = PrioritizeDayOutput(
            priorities: priorities,
            warnings: warnings,
            recommendations: recommendations,
            informationGaps: informationGaps
        )

        let encodedOutput = try JSONEncoder().encode(output)

        return try JSONDecoder().decode(
            Inference.Output.self,
            from: encodedOutput
        )
    }

    func inputs() -> [PrioritizeDayInput] {
        receivedInputs
    }
}

extension AgenticDomainsFlowTesting {
    static func runPrepareDayProgram() async throws
        -> [TestFlowDiagnostic]
    {
        let calendar = PrepareDayCalendarFixture()
        let reminders = PrepareDayRemindersFixture()
        let weather = PrepareDayWeatherFixture()
        let inference = PrepareDayInferenceFixture()

        var registry = ProgramRegistry()

        try AgenticAppleServicesProgramSet(
            calendar: calendar,
            reminders: reminders,
            weather: weather
        ).register(
            into: &registry
        )

        try Expect.equal(
            registry.count,
            2,
            "AgenticAppleServices Program set registers its read and mutation Programs"
        )

        try Expect.equal(
            registry.descriptors
                .map {
                    $0.identifier.rawValue
                }
                .sorted(),
            [
                "apple_services.create_reminder",
                "apple_services.prepare_day",
            ],
            "AgenticAppleServices exposes its read and mutation Programs through ProgramRegistry"
        )

        let program = PrepareDayProgram(
            calendar: calendar,
            reminders: reminders,
            weather: weather
        )
        let context = AgentProgramContext(
            inference: inference
        )
        let coordinate = WeatherCoordinate(
            latitude: 52.3676,
            longitude: 4.9041
        )
        let input = PrepareDayInput(
            startDate: "2026-09-12T00:00:00Z",
            endDate: "2026-09-13T00:00:00Z",
            weatherCoordinate: coordinate,
            context: "Protect focus time."
        )

        let plan = try await program.run(
            input,
            in: context
        )

        try Expect.equal(
            plan.events.first?.title ?? "",
            "Design review",
            "PrepareDayProgram preserves deterministic Calendar facts"
        )
        try Expect.equal(
            plan.reminders.first?.title ?? "",
            "File expenses",
            "PrepareDayProgram preserves deterministic Reminder facts"
        )
        try Expect.equal(
            plan.weather?.daily.first?.conditionCode ?? "",
            "rain",
            "PrepareDayProgram preserves deterministic Weather facts"
        )
        try Expect.equal(
            plan.priorities.first?.title ?? "",
            "Design review",
            "PrepareDayProgram uses PrioritizeDay semantic output"
        )
        try Expect.equal(
            plan.recommendations.first?.action ?? "",
            "Respect the supplied day context",
            "PrepareDayProgram carries typed semantic recommendations into DayPlan"
        )
        try Expect.equal(
            plan.recommendations.first?.rationale ?? "",
            "Protect focus time.",
            "PrepareDayProgram preserves recommendation rationale"
        )
        try Expect.equal(
            plan.warnings.first?.summary ?? "",
            "Meaningful precipitation risk",
            "PrepareDayProgram carries typed semantic warnings into DayPlan"
        )
        try Expect.equal(
            plan.informationGaps.count,
            0,
            "PrepareDayProgram reports no information gap when Weather was supplied"
        )

        let calendarQueries = await calendar.queries()
        let reminderLimits = await reminders.limits()
        let weatherCalls = await weather.calls()
        let inferenceInputs = await inference.inputs()

        try Expect.equal(
            calendarQueries.count,
            1,
            "PrepareDayProgram performs one Calendar read"
        )
        try Expect.equal(
            calendarQueries.first?.startDate ?? "",
            input.startDate,
            "PrepareDayProgram forwards the requested Calendar start"
        )
        try Expect.equal(
            calendarQueries.first?.endDate ?? "",
            input.endDate,
            "PrepareDayProgram forwards the requested Calendar end"
        )
        try Expect.equal(
            calendarQueries.first?.limit ?? 0,
            50,
            "PrepareDayProgram bounds Calendar reads"
        )
        try Expect.equal(
            reminderLimits,
            [50],
            "PrepareDayProgram bounds Reminder reads"
        )
        try Expect.equal(
            weatherCalls.count,
            1,
            "PrepareDayProgram performs one Weather read when coordinate is supplied"
        )
        try Expect.equal(
            weatherCalls.first?.coordinate,
            coordinate,
            "PrepareDayProgram uses the explicitly supplied Weather coordinate"
        )
        try Expect.equal(
            weatherCalls.first?.hours ?? 0,
            24,
            "PrepareDayProgram bounds hourly Weather reads"
        )
        try Expect.equal(
            weatherCalls.first?.days ?? 0,
            2,
            "PrepareDayProgram bounds daily Weather reads"
        )
        try Expect.equal(
            inferenceInputs.count,
            1,
            "PrepareDayProgram performs exactly one PrioritizeDay inference"
        )
        try Expect.equal(
            inferenceInputs.first?.events.first?.title ?? "",
            "Design review",
            "PrioritizeDay receives the deterministic Calendar facts"
        )
        try Expect.equal(
            inferenceInputs.first?.reminders.first?.title ?? "",
            "File expenses",
            "PrioritizeDay receives the deterministic Reminder facts"
        )
        try Expect.equal(
            inferenceInputs.first?.weather?.daily.first?.conditionCode ?? "",
            "rain",
            "PrioritizeDay receives the deterministic Weather facts"
        )

        let noWeatherCalendar = PrepareDayCalendarFixture()
        let noWeatherReminders = PrepareDayRemindersFixture()
        let noWeatherProvider = PrepareDayWeatherFixture()
        let noWeatherInference = PrepareDayInferenceFixture()
        let noWeatherProgram = PrepareDayProgram(
            calendar: noWeatherCalendar,
            reminders: noWeatherReminders,
            weather: noWeatherProvider
        )
        let noWeatherPlan = try await noWeatherProgram.run(
            PrepareDayInput(
                startDate: input.startDate,
                endDate: input.endDate,
                context: input.context
            ),
            in: AgentProgramContext(
                inference: noWeatherInference
            )
        )
        let noWeatherCalls = await noWeatherProvider.calls()

        try Expect.equal(
            noWeatherCalls.count,
            0,
            "PrepareDayProgram does not invoke Weather without an explicit coordinate"
        )
        try Expect.true(
            noWeatherPlan.weather == nil,
            "PrepareDayProgram leaves Weather absent without an explicit coordinate"
        )
        try Expect.equal(
            noWeatherPlan.warnings.count,
            0,
            "Missing Weather is not misclassified as a warning"
        )
        try Expect.equal(
            noWeatherPlan.informationGaps.first?.subject ?? "",
            "weather",
            "PrioritizeDay classifies absent Weather as an information gap"
        )
        try Expect.equal(
            noWeatherPlan.informationGaps.first?.reason ?? "",
            "No weather coordinate was supplied, so weather was not read.",
            "PrepareDayProgram preserves typed information-gap rationale"
        )

        return [
            .field(
                "program",
                PrepareDayProgram.descriptor.identifier.rawValue
            ),
            .field(
                "inference",
                PrioritizeDay.definition.identifier.rawValue
            ),
            .field(
                "events",
                "\(plan.events.count)"
            ),
            .field(
                "reminders",
                "\(plan.reminders.count)"
            ),
            .field(
                "weather_calls",
                "\(weatherCalls.count)"
            ),
            .field(
                "weatherless_calls",
                "\(noWeatherCalls.count)"
            ),
            .field(
                "warnings",
                "\(plan.warnings.count)"
            ),
            .field(
                "recommendations",
                "\(plan.recommendations.count)"
            ),
            .field(
                "information_gaps",
                "\(noWeatherPlan.informationGaps.count)"
            ),
        ]
    }
}
