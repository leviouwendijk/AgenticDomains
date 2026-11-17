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

enum SchedulingReservedHoursTests {
    static let source = """
    import Scheduling;

    let sessions: Calendar = .{ .title = "Sessions" };
    let slots: Calendar = .{ .title = "Slots", .role = .offers };

    let trainer: Participant = .{
        .workingHours = .{ .tuesday = ["10:00-21:00"], .saturday = ["10:00-21:00"] },
        .reservedHours = .{ .tuesday = ["10:00-21:00"] },
        .calendars = [sessions, slots],
    };

    let scheduling: SchedulingSettings = .{
        .timeZone = "Europe/Amsterdam",
        .defaultDurationMinutes = 90,
    };
    """

    static let events: [ScheduledEvent] = [
        SchedulingFixture.event("Concept", "2026-12-08T14:00:00+01:00", "2026-12-08T15:30:00+01:00", calendar: "Slots", availability: .free),
    ]

    static func run() async throws {
        let runtime = try SchedulingConfiguration(source: source)
            .runtime(sources: [FixtureCalendarSource(entries: events)])
        let context = try SchedulingFixture.context(runtime)

        func evaluate(_ start: String, escalate: Bool? = nil) async throws -> Scheduling.Tools.Evaluate.Output {
            try await Scheduling.Tools.Evaluate().call(
                .init(start: start, requirements: .init(allow_reserved: escalate)),
                in: context
            )
        }

        let devDay = try await evaluate("2026-12-08T11:00:00+01:00")
        try Expect.equal(devDay.violations.map(\.constraint), [.reserved], "Tuesday is held back by default")
        try Expect.true(devDay.violations.first?.detail.contains("tuesday 10:00-21:00") ?? false, "Names the reserved hours")

        let slotted = try await evaluate("2026-12-08T14:00:00+01:00")
        try Expect.true(slotted.feasible, "A concept slot opens reserved hours")
        try Expect.equal(slotted.placement, .offered, "Booked into the slot")

        let escalated = try await evaluate("2026-12-08T11:00:00+01:00", escalate: true)
        try Expect.true(escalated.feasible, "Escalation opens reserved hours")
        try Expect.equal(escalated.placement, .reserved, "Marked as an escalation")

        let weekend = try await evaluate("2026-12-12T11:00:00+01:00")
        try Expect.true(weekend.feasible, "Saturday is open")
        try Expect.equal(weekend.placement, .open, "Nothing offered on Saturday")
    }
}

enum SchedulingSharedTravelTests {
    static let source = """
    import Scheduling;

    let sessionsA: Calendar = .{ .title = "Sessions A" };
    let sessionsB: Calendar = .{ .title = "Sessions B" };
    let duo: Calendar = .{ .title = "Duo", .sharedTravel = true };
    let slotsA: Calendar = .{ .title = "Slots A", .role = .offers, .offerTitles = ["Slot"] };
    let cancelled: Calendar = .{ .title = "Cancelled", .role = .records };

    let a: Participant = .{
        .workingHours = .{ .saturday = ["10:00-21:00"], .sunday = ["10:00-21:00"] },
        .calendars = [sessionsA, duo, slotsA, cancelled],
    };
    let b: Participant = .{
        .workingHours = .{ .saturday = ["10:00-21:00"], .sunday = ["10:00-21:00"] },
        .calendars = [sessionsB, duo],
    };

    let scheduling: SchedulingSettings = .{
        .timeZone = "Europe/Amsterdam",
        .defaultDurationMinutes = 90,
    };
    """

    static let events: [ScheduledEvent] = [
        // Saturday: after the duo, a continues to Diemen and b goes home.
        SchedulingFixture.event("Duo: Mirjam", "2026-12-12T13:00:00+01:00", "2026-12-12T14:30:00+01:00", calendar: "Duo", location: "Amsterdam"),
        SchedulingFixture.event("Session: Diemen", "2026-12-12T15:30:00+01:00", "2026-12-12T17:00:00+01:00", calendar: "Sessions A", location: "Diemen"),
        SchedulingFixture.event("Slot 1", "2026-12-12T10:00:00+01:00", "2026-12-12T11:30:00+01:00", calendar: "Slots A", availability: .free),
        SchedulingFixture.event("o.v. Client | Dog", "2026-12-12T18:00:00+01:00", "2026-12-12T19:30:00+01:00", calendar: "Slots A", availability: .free),
        SchedulingFixture.event("Cancelled: Jan", "2026-12-12T11:30:00+01:00", "2026-12-12T13:00:00+01:00", calendar: "Cancelled"),
        // Sunday: only a duo.
        SchedulingFixture.event("Duo: Zoey", "2026-12-13T13:00:00+01:00", "2026-12-13T14:30:00+01:00", calendar: "Duo", location: "Amsterdam"),
    ]

    static func run() async throws {
        let runtime = try SchedulingConfiguration(source: source)
            .runtime(sources: [FixtureCalendarSource(entries: events)])
        let context = try SchedulingFixture.context(runtime)

        let conflicts = try await Scheduling.Tools.Conflicts().call(
            .init(window_start: "2026-12-12T00:00:00+01:00", window_end: "2026-12-13T00:00:00+01:00", participants: ["b"]),
            in: context
        )
        let split = conflicts.conflicts.first { $0.kind == .split_travel }
        try Expect.equal(split?.participant, "a", "a continues elsewhere, found from b's side too")
        try Expect.equal(split?.second.title, "Session: Diemen", "Names where the trip splits")
        try Expect.true(split?.detail?.contains("b to home") ?? false, "Says who goes home")

        func evaluate(_ start: String, _ participants: [String], allow: Bool? = nil) async throws -> Scheduling.Tools.Evaluate.Output {
            try await Scheduling.Tools.Evaluate().call(
                .init(start: start, requirements: .init(participants: participants, allow_split_travel: allow)),
                in: context
            )
        }

        let solo = try await evaluate("2026-12-13T15:00:00+01:00", ["a"])
        try Expect.equal(solo.violations.map(\.constraint), [.split_travel], "A solo session right after the duo splits the trip")
        try Expect.true(try await evaluate("2026-12-13T15:00:00+01:00", ["a"], allow: true).feasible, "Escalation allows a second vehicle")
        let together = try await Scheduling.Tools.Evaluate().call(
            .init(start: "2026-12-13T15:00:00+01:00", requirements: .init(participants: ["a", "b"], location: "Amsterdam")),
            in: context
        )
        try Expect.true(together.feasible, "Both continuing together keeps the trip whole")
        let morning = try await evaluate("2026-12-13T10:00:00+01:00", ["a"])
        try Expect.equal(morning.violations.map(\.constraint), [.split_travel], "Coming from a solo session, a would arrive separately")

        let provisional = try await evaluate("2026-12-12T18:00:00+01:00", ["a"])
        try Expect.true(provisional.violations.contains { $0.constraint == .busy }, "A provisional booking in a slots calendar blocks")

        let agenda = try await Scheduling.Tools.Agenda().call(
            .init(window_start: "2026-12-12T00:00:00+01:00", window_end: "2026-12-13T00:00:00+01:00", participants: ["a"]),
            in: context
        )
        let entries = agenda.participants.first?.entries ?? []
        try Expect.equal(entries.first { $0.title == "Slot 1" }?.reading, .offer, "Titled as a slot: open")
        try Expect.equal(entries.first { $0.title == "o.v. Client | Dog" }?.reading, .provisional, "Titled otherwise: provisional")
        try Expect.false(entries.contains { $0.title == "Cancelled: Jan" }, "Records are left out by default")
        try Expect.equal(agenda.participants.first?.hidden_records, 1, "And counted")
    }
}
