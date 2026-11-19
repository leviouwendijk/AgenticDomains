import Agentic
import AgenticScheduling
import Foundation
import Testing

private typealias F = SchedulingFixture

/// The fixture's events, plus a record of what was written.
private actor WritableFixtureSource: CalendarSource {
    nonisolated let identifier = "fixture"
    private let fixture = FixtureCalendarSource(entries: F.events)
    private(set) var written: [EventDraft] = []

    func authorization() async -> CalendarSourceAuthorization { .authorized }

    func calendars() async throws -> [CalendarReference] {
        try await fixture.calendars()
    }

    func events(in interval: ScheduleInterval) async throws -> [ScheduledEvent] {
        try await fixture.events(in: interval)
    }

    func create(_ draft: EventDraft) async throws -> ScheduledEvent {
        written.append(draft)
        return ScheduledEvent(
            source: identifier,
            identifier: "written.\(written.count)",
            title: draft.title,
            interval: draft.interval,
            isAllDay: false,
            calendar: draft.calendar,
            availability: draft.availability,
            location: draft.location
        )
    }
}

/// Booking writes into the participants' commitments calendar, reports
/// what it overlaps, and refuses what it cannot place.
enum SchedulingBookingTests {
    private static func context(_ source: any CalendarSource) throws -> ToolContext {
        let base = F.runtime()
        return try F.context(Scheduling.Runtime(
            sources: [source],
            participants: base.participants,
            calendars: base.calendars,
            places: base.places,
            defaults: base.defaults
        ))
    }

    static func run() async throws {
        let source = WritableFixtureSource()
        let context = try context(source)
        let book = Scheduling.Tools.Book()

        let clean = try await book.call(
            .init(title: "Intake", start: "2026-11-23T15:00:00+01:00", location: "office"),
            in: context
        )
        try Expect.equal(clean.calendar, "Levi", "Primary participant's commitments calendar")
        try Expect.equal(clean.end, "2026-11-23T16:00:00+01:00", "Configured duration")
        try Expect.equal(clean.overlaps, [], "Nothing in the way")
        let locations = await source.written.map(\.location)
        try Expect.equal(locations, ["office"], "Written with its location")

        let clash = Scheduling.Tools.Book.Input(title: "Call", start: "2026-11-23T09:30:00+01:00", duration_minutes: 30)
        let preflight = try await book.preflight(clash, in: context)
        try Expect.true(preflight.warnings.contains { $0.contains("Standup") }, "Approval names the overlap")
        let overlapping = try await book.call(clash, in: context)
        try Expect.true(overlapping.overlaps.contains { $0.contains("Standup") }, "Result names the overlap")

        do {
            _ = try await book.call(.init(title: "Joint", start: "2026-11-23T15:00:00+01:00", participants: ["levi", "anna"]), in: context)
            try Expect.true(false, "No shared calendar must throw")
        } catch Scheduling.Tools.Book.Failure.noDefaultCalendar {}

        let named = try await book.call(
            .init(title: "Joint", start: "2026-11-23T15:00:00+01:00", participants: ["levi", "anna"], calendar: "anna"),
            in: context
        )
        try Expect.equal(named.calendar, "Anna", "Named calendar, by identifier")
        let writes = await source.written.count
        try Expect.equal(writes, 3, "One write per booking")

        do {
            _ = try await book.call(.init(title: "Intake", start: "2026-11-23T15:00:00+01:00"), in: try F.context())
            try Expect.true(false, "A read-only source must throw")
        } catch CalendarSourceWriteFailure.readOnly {}
    }
}
