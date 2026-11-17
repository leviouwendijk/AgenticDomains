import Agentic
import AgenticScheduling
import Foundation
import Testing

/// Two trainers with their own sessions, a shared duo calendar, offered
/// concept slots, cancellation records and an internal day, on Wednesday
/// 2026-11-25 and Thursday 2026-11-26.
private enum TeamFixture {
    typealias F = SchedulingFixture

    static let wednesday = (start: "2026-11-25T00:00:00+01:00", end: "2026-11-26T00:00:00+01:00")
    static let thursday = (start: "2026-11-26T00:00:00+01:00", end: "2026-11-27T00:00:00+01:00")

    static let events: [ScheduledEvent] = [
        F.event("Cancelled: Jansen", "2026-11-25T09:00:00+01:00", "2026-11-25T10:00:00+01:00", calendar: "Cancelled A"),
        F.event("Concept", "2026-11-25T10:00:00+01:00", "2026-11-25T11:00:00+01:00", calendar: "Concept A", availability: .free),
        F.event("Session: de Vries", "2026-11-25T11:30:00+01:00", "2026-11-25T12:30:00+01:00", calendar: "Sessions A"),
        F.event("Duo: Bakker", "2026-11-25T12:40:00+01:00", "2026-11-25T13:40:00+01:00", calendar: "Duo"),
        F.event("Concept", "2026-11-25T14:10:00+01:00", "2026-11-25T15:10:00+01:00", calendar: "Concept A", availability: .free),
        F.event("Concept", "2026-11-25T10:00:00+01:00", "2026-11-25T11:00:00+01:00", calendar: "Concept B", availability: .free),
        F.event("Internal day", "2026-11-26T00:00:00+01:00", "2026-11-27T00:00:00+01:00", calendar: "Internal A", availability: .free, allDay: true),
        F.event("Session: Visser", "2026-11-26T10:00:00+01:00", "2026-11-26T11:00:00+01:00", calendar: "Sessions A"),
    ]

    static func runtime() throws -> Scheduling.Runtime {
        let weekdays = WorkingHours.weekdays
        let wednesdays = WorkingHours([.wednesday: weekdays.ranges(on: .wednesday)])
        return Scheduling.Runtime(
            sources: [FixtureCalendarSource(entries: events)],
            participants: [
                .init(identifier: "trainer_a", name: "Trainer A", timeZone: F.zone,
                      calendars: ["Sessions A", "Duo", "Cancelled A", "Concept A", "Internal A"]),
                .init(identifier: "trainer_b", name: "Trainer B", timeZone: F.zone, workingHours: wednesdays,
                      calendars: ["Sessions B", "Duo", "Cancelled B", "Concept B"]),
            ],
            calendars: [
                .init("Sessions A", overrun: try ScheduleMinutes(15)),
                .init("Sessions B", overrun: try ScheduleMinutes(15)),
                .init("Duo", overrun: try ScheduleMinutes(20)),
                .init("Concept A", role: .offers),
                .init("Concept B", role: .offers),
                .init("Cancelled A", role: .records),
                .init("Cancelled B", role: .records),
                .init("Internal A", role: .reserved),
            ],
            defaults: .init(timeZone: F.zone)
        )
    }

    static func find(
        _ requirements: SlotRequirements,
        window: (start: String, end: String) = wednesday,
        limit: Int = 3
    ) async throws -> Scheduling.Tools.FindSlots.Output {
        try await Scheduling.Tools.FindSlots().call(
            .init(window_start: window.start, window_end: window.end, requirements: requirements, step_minutes: 30, limit: limit),
            in: try F.context(runtime())
        )
    }
}

private func times(_ candidates: [SlotCandidate]) -> [String] {
    candidates.map { String($0.start.dropFirst(11).prefix(5)) }
}

enum SchedulingTeamWorkflowTests {
    static func offeredSlotsPreferred() async throws {
        let result = try await TeamFixture.find(.init(duration_minutes: 60, participants: ["trainer_a"]))
        try Expect.equal(times(result.candidates).prefix(2).map { $0 }, ["10:00", "14:10"], "Offered slots first, including off-grid ones")
        try Expect.equal(result.candidates.prefix(2).map(\.placement), [.offered, .offered], "Both offered")

        let open = try await TeamFixture.find(
            .init(duration_minutes: 60, participants: ["trainer_a"], placement: .any),
            limit: 1
        )
        try Expect.equal(times(open.candidates), ["09:00"], "A cancellation record does not block")
        try Expect.equal(open.candidates.first?.placement, .open, "Nobody offered nine o'clock")
    }

    static func offeredOnlyForDuo() async throws {
        let solo = try await TeamFixture.find(
            .init(duration_minutes: 60, participants: ["trainer_a"], placement: .offered_only),
            limit: 5
        )
        try Expect.equal(times(solo.candidates), ["10:00", "14:10"], "Only inside trainer A's concept slots")

        let duo = try await TeamFixture.find(
            .init(duration_minutes: 60, participants: ["trainer_a", "trainer_b"], placement: .offered_only),
            limit: 5
        )
        try Expect.equal(times(duo.candidates), ["10:00"], "Both trainers offered ten o'clock only")
        try Expect.contains(duo.rejected.map(\.constraint), .not_offered, "Uncovered times rejected")
    }

    static func reservedTimeIsAnEscalation() async throws {
        let standard = try await TeamFixture.find(
            .init(duration_minutes: 60, participants: ["trainer_a"]),
            window: TeamFixture.thursday
        )
        try Expect.equal(standard.candidates.count, 0, "Internal day blocks despite being marked free")
        try Expect.equal(standard.reserved_only_rejections, 12, "Twelve working-hour starts blocked only by the internal day")
        try Expect.true(standard.information_gaps.contains { $0.contains("escalation") }, "Escalation suggested")

        let escalated = try await TeamFixture.find(
            .init(duration_minutes: 60, participants: ["trainer_a"], allow_reserved: true),
            window: TeamFixture.thursday
        )
        try Expect.equal(times(escalated.candidates).first, "09:00", "Opens the internal day")
        try Expect.equal(escalated.candidates.first?.placement, .reserved, "Marked as an escalation")
        try Expect.false(times(escalated.candidates).contains("10:00"), "The session still blocks")
    }

    static func overrunIsASoftMargin() async throws {
        let evaluation = try await Scheduling.Tools.Evaluate().call(
            .init(start: "2026-11-25T13:50:00+01:00", requirements: .init(duration_minutes: 60, participants: ["trainer_a"])),
            in: try SchedulingFixture.context(TeamFixture.runtime())
        )
        try Expect.true(evaluation.feasible, "Ten minutes after the duo is still feasible")
        let margin = evaluation.terms.first { $0.kind == .overrun_margin }
        try Expect.equal(margin?.satisfaction, 0.5, "Half of the duo's usual 20-minute overrun fits")
        try Expect.equal(evaluation.placement, .open, "13:50 is not inside the 14:10 offer")
    }

    static func conflicts() async throws {
        let result = try await Scheduling.Tools.Conflicts().call(
            .init(window_start: TeamFixture.wednesday.start, window_end: TeamFixture.thursday.end, participants: ["trainer_a"]),
            in: try SchedulingFixture.context(TeamFixture.runtime())
        )
        try Expect.equal(result.conflicts.map(\.kind), [.overrun_risk, .in_reserved_time], "Overrun risk, then a session on the internal day")
        try Expect.equal(result.conflicts[0].gap_minutes, 10, "Ten minutes between session and duo")
        try Expect.equal(result.conflicts[0].required_minutes, 15, "Sessions usually run fifteen over")
        try Expect.equal(result.conflicts[1].gap_minutes, -60, "The whole session lies in reserved time")
    }

    static func busyShowsReservedAndOpenOffers() async throws {
        let result = try await Scheduling.Tools.Busy().call(
            .init(window_start: TeamFixture.wednesday.start, window_end: TeamFixture.thursday.end, participants: ["trainer_a"]),
            in: try SchedulingFixture.context(TeamFixture.runtime())
        )
        let trainer = try requireFirst(result.participants)
        try Expect.equal(trainer.blocks.map(\.events), [["Session: de Vries"], ["Duo: Bakker"], ["Session: Visser"]], "Commitments only")
        try Expect.equal(trainer.reserved.map(\.events), [["Internal day"]], "Internal day reserved")
        try Expect.equal(trainer.open_offers.count, 2, "Both concept slots still open")
    }

    static func calendarsShowRoles() async throws {
        let result = try await Scheduling.Tools.ListCalendars().call(
            .init(),
            in: try SchedulingFixture.context(TeamFixture.runtime())
        )
        let calendars = try requireFirst(result.sources).calendars
        try Expect.equal(calendars.first { $0.title == "Duo" }?.participants, ["trainer_a", "trainer_b"], "Duo shared by both")
        try Expect.equal(calendars.first { $0.title == "Concept B" }?.role, .offers, "Concept calendar offers")
        try Expect.equal(calendars.first { $0.title == "Sessions A" }?.overrun_minutes, 15, "Overrun reported")
        try Expect.true(result.information_gaps.contains { $0.contains("Sessions B") }, "Configured but invisible calendar reported")
    }
}

private struct MissingElement: Error {}

private func requireFirst<Element>(_ elements: [Element]) throws -> Element {
    guard let first = elements.first else {
        throw MissingElement()
    }
    return first
}
