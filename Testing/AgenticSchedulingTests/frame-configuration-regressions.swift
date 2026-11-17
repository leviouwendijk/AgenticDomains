import Agentic
import AgenticScheduling
import Foundation
import Testing

enum SchedulingFrameTests {
    static let team = """
    import Scheduling;

    let sessionsA: Calendar = .{ .title = "Sessions A", .overrunMinutes = 15 };
    let sessionsB: Calendar = .{ .title = "Sessions B", .overrunMinutes = 15 };
    let duo: Calendar = .{ .title = "Duo", .overrunMinutes = 20 };
    let conceptA: Calendar = .{ .title = "Concept A", .role = .offers };
    let conceptB: Calendar = .{ .title = "Concept B", .role = .offers };
    let cancelledA: Calendar = .{ .title = "Cancelled A", .role = .records };
    let cancelledB: Calendar = .{ .title = "Cancelled B", .role = .records };
    let internalA: Calendar = .{ .title = "Internal A", .role = .reserved };

    let trainer_a: Participant = .{
        .name = "Trainer A",
        .calendars = [sessionsA, duo, cancelledA, conceptA, internalA],
    };

    let trainer_b: Participant = .{
        .name = "Trainer B",
        .workingHours = .{ .wednesday = ["09:00-17:00"] },
        .calendars = [sessionsB, duo, cancelledB, conceptB],
    };

    let office: Place = .{
        .label = "Office",
        .latitude = 52.3676,
        .longitude = 4.9041,
        .aliases = ["kantoor"],
    };

    let scheduling: SchedulingSettings = .{
        .timeZone = "Europe/Amsterdam",
        .placement = .prefer_offered,
    };
    """

    static func readsTeam() async throws {
        let configuration = try SchedulingConfiguration(source: team, filePath: "scheduling.frame")
        try Expect.equal(configuration.participants.map(\.identifier), ["trainer_a", "trainer_b"], "Binding names, in order")
        try Expect.equal(configuration.participants[1].name, "Trainer B", "Display name")
        try Expect.equal(configuration.participants[1].workingHours.ranges(on: .monday).count, 0, "Only Wednesday is worked")
        try Expect.equal(configuration.participants[0].timeZone.raw, "Europe/Amsterdam", "Zone from settings")
        try Expect.equal(configuration.calendars.count, 0, "Every calendar belongs to a participant")

        let runtime = configuration.runtime(sources: [FixtureCalendarSource(entries: TeamFixture.events)])
        try Expect.equal(runtime.calendars.count, 8, "Shared duo calendar counted once")

        let duo = try await Scheduling.Tools.FindSlots().call(
            .init(
                window_start: TeamFixture.wednesday.start,
                window_end: TeamFixture.wednesday.end,
                requirements: .init(duration_minutes: 60, participants: ["Trainer A", "trainer_b"], placement: .offered_only),
                step_minutes: 30,
                limit: 5
            ),
            in: try SchedulingFixture.context(runtime)
        )
        try Expect.equal(duo.candidates.map { String($0.start.dropFirst(11).prefix(5)) }, ["10:00"], "Same answer as the Swift-built runtime")

        let travel = try await Scheduling.Tools.EstimateTravel().call(
            .init(origin: "Kantoor", destination: "office"),
            in: try SchedulingFixture.context(runtime)
        )
        try Expect.equal(travel.estimate?.method, .same_place, "Alias and binding name resolve to the place")
    }

    static func rejectsInvalid() throws {
        try expectFailure("Misspelt calendar reference", containing: "sessionA") {
            team.replacingOccurrences(of: "[sessionsA, duo", with: "[sessionA, duo")
        }
        try expectFailure("Bad working-hours range", containing: "trainer_b.workingHours.wednesday[0]") {
            team.replacingOccurrences(of: "\"09:00-17:00\"", with: "\"17:00-09:00\"")
        }
        try expectFailure("Unknown zone", containing: "scheduling.timeZone") {
            team.replacingOccurrences(of: "Europe/Amsterdam", with: "Europe/Atlantis")
        }
        try expectFailure("Unknown field", containing: "colour") {
            team.replacingOccurrences(of: ".role = .offers }", with: ".role = .offers, .colour = \"red\" }")
        }
        try expectFailure("Same calendar declared differently", containing: "Duo") {
            team + "\nlet duoAgain: Calendar = .{ .title = \"duo\", .role = .records };\n"
        }
    }

    static func reportsConfigurationState() async throws {
        let missing = ToolContext(services: try ToolServices().inserting(
            Scheduling.ConfigurationState.missing(expected: "/home/.agentic/domains/scheduling.frame")
        ))
        try await expectToolFailure(missing, containing: "/home/.agentic/domains/scheduling.frame")

        let invalid = ToolContext(services: try ToolServices().inserting(
            Scheduling.ConfigurationState.invalid(file: "scheduling.frame", message: "line 3: unknown type")
        ))
        try await expectToolFailure(invalid, containing: "line 3: unknown type")

        try await expectToolFailure(ToolContext(), containing: "does not provide scheduling")
    }

    private static func expectFailure(_ label: String, containing text: String, _ source: () -> String) throws {
        do {
            _ = try SchedulingConfiguration(source: source())
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            try Expect.true(message.contains(text), "\(label): '\(message)' names \(text)")
            return
        }
        try Expect.true(false, "\(label) must fail")
    }

    private static func expectToolFailure(_ context: ToolContext, containing text: String) async throws {
        do {
            _ = try await Scheduling.Tools.ListCalendars().call(.init(), in: context)
        } catch {
            let message = error.localizedDescription
            try Expect.true(message.contains(text), "'\(message)' names \(text)")
            return
        }
        try Expect.true(false, "Tool must fail without a runtime")
    }
}

enum SchedulingAllDayRoleTests {
    static let source = """
    import Scheduling;

    let internal: Calendar = .{ .title = "Internal", .role = .commitments, .allDayRole = .reserved };
    let sessions: Calendar = .{ .title = "Sessions" };

    let trainer: Participant = .{ .calendars = [sessions, internal] };

    let scheduling: SchedulingSettings = .{ .timeZone = "Europe/Amsterdam" };
    """

    static let events: [ScheduledEvent] = [
        SchedulingFixture.event("Office day", "2026-11-30T00:00:00+01:00", "2026-12-01T00:00:00+01:00", calendar: "Internal", availability: .free, allDay: true),
        SchedulingFixture.event("Team meeting", "2026-12-01T10:00:00+01:00", "2026-12-01T11:00:00+01:00", calendar: "Internal"),
    ]

    static func run() async throws {
        let runtime = try SchedulingConfiguration(source: source)
            .runtime(sources: [FixtureCalendarSource(entries: events)])
        let context = try SchedulingFixture.context(runtime)

        let officeDay = try await Scheduling.Tools.FindSlots().call(
            .init(
                window_start: "2026-11-30T00:00:00+01:00",
                window_end: "2026-12-01T00:00:00+01:00",
                requirements: .init(duration_minutes: 60),
                step_minutes: 60
            ),
            in: context
        )
        try Expect.equal(officeDay.candidates.count, 0, "An all-day office day is reserved although marked free")
        try Expect.equal(officeDay.reserved_only_rejections, 8, "Every working hour opens by escalation")

        let meeting = try await Scheduling.Tools.Evaluate().call(
            .init(start: "2026-12-01T10:00:00+01:00", requirements: .init(duration_minutes: 60, allow_reserved: true)),
            in: context
        )
        try Expect.equal(meeting.violations.map(\.constraint), [.busy], "A timed meeting blocks, even with escalation")

        let calendars = try await Scheduling.Tools.ListCalendars().call(.init(), in: context)
        let office = try calendarNamed("Internal", in: calendars)
        try Expect.equal(office.role, .commitments, "Timed events are commitments")
        try Expect.equal(office.all_day_role, .reserved, "All-day events are reserved")
    }

    private struct MissingCalendar: Error {}

    private static func calendarNamed(
        _ title: String,
        in output: Scheduling.Tools.ListCalendars.Output
    ) throws -> Scheduling.Tools.ListCalendars.CalendarSummary {
        guard let calendar = output.sources.flatMap(\.calendars).first(where: { $0.title == title }) else {
            throw MissingCalendar()
        }
        return calendar
    }
}

enum SchedulingTravelPreferenceTests {
    static let source = """
    import Scheduling;

    let sessions: Calendar = .{ .title = "Sessions", .overrunMinutes = 30 };

    let trainer: Participant = .{
        .workingHours = .{
            .monday = ["10:00-21:00"],
            .tuesday = ["10:00-21:00"],
        },
        .calendars = [sessions],
        .home = "home",
    };

    let home: Place = .{ .latitude = 52.6317, .longitude = 4.7485 };
    let schoorl: Place = .{ .latitude = 52.7016, .longitude = 4.6895 };
    let bergen: Place = .{ .latitude = 52.6696, .longitude = 4.7056 };

    let scheduling: SchedulingSettings = .{
        .timeZone = "Europe/Amsterdam",
        .defaultDurationMinutes = 90,
        .defaultOverrunMinutes = 30,
        .preferredHours = "10:00-17:00",
    };
    """

    static let events: [ScheduledEvent] = [
        SchedulingFixture.event("Session", "2026-12-07T10:00:00+01:00", "2026-12-07T11:30:00+01:00", calendar: "Sessions", location: "schoorl"),
    ]

    static func run() async throws {
        let runtime = try SchedulingConfiguration(source: source)
            .runtime(sources: [FixtureCalendarSource(entries: events)])
        let context = try SchedulingFixture.context(runtime)

        func evaluate(_ start: String) async throws -> Scheduling.Tools.Evaluate.Output {
            try await Scheduling.Tools.Evaluate().call(
                .init(start: start, requirements: .init(location: "bergen")),
                in: context
            )
        }

        let nearby = try await evaluate("2026-12-07T12:00:00+01:00")
        let alone = try await evaluate("2026-12-08T12:00:00+01:00")
        try Expect.equal(nearby.end, "2026-12-07T13:30:00+01:00", "Configured 90-minute default")

        let nearbyTravel = nearby.terms.first { $0.kind == .added_travel }
        let aloneTravel = alone.terms.first { $0.kind == .added_travel }
        try Expect.true(
            (nearbyTravel?.satisfaction ?? 0) > (aloneTravel?.satisfaction ?? 1),
            "Next to a session in Schoorl adds less travel than a separate trip from home"
        )
        try Expect.true(aloneTravel?.detail?.contains("trainer") ?? false, "Detail names the participant")
        try Expect.equal(
            nearby.terms.first { $0.kind == .time_of_day }?.detail,
            "10:00-17:00",
            "Preferred hours scored without a request preference"
        )

        let margin = nearby.terms.first { $0.kind == .overrun_margin }
        try Expect.equal(margin?.satisfaction, 1, "Thirty free minutes after the Schoorl session")

        let evening = try await evaluate("2026-12-07T19:00:00+01:00")
        try Expect.true(evening.feasible, "Evenings are possible")
        try Expect.true(
            (evening.terms.first { $0.kind == .time_of_day }?.satisfaction ?? 1) < 1,
            "Evenings score lower"
        )
    }
}
