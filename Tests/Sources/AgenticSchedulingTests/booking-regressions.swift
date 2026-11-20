import Agentic
import AgenticScheduling
import Foundation
import Reporting
import Testing

private typealias F = SchedulingFixture

/// A calendar source that applies writes to its own list of events.
private actor WritableFixtureSource: CalendarSource {
    nonisolated let identifier = "fixture"
    private let calendarList: [CalendarReference]
    private(set) var entries: [ScheduledEvent]
    private var written = 0

    init(entries: [ScheduledEvent], calendars: [String]) {
        self.entries = entries
        self.calendarList = calendars.map { .init(identifier: $0.lowercased(), title: $0) }
    }

    func authorization() async -> CalendarSourceAuthorization { .authorized }

    /// Like Apple Calendar: no travel time, no attachments.
    nonisolated var storedDetails: Set<EventDetail> { [.notes, .url, .alerts, .recurrence] }

    func calendars() async throws -> [CalendarReference] { calendarList }

    func events(in interval: ScheduleInterval) async throws -> [ScheduledEvent] {
        entries.filter { $0.interval.overlaps(interval) }
    }

    func create(_ draft: EventDraft) async throws -> ScheduledEvent {
        written += 1
        let event = ScheduledEvent(
            source: identifier,
            identifier: "written.\(written)",
            title: draft.title,
            interval: draft.interval,
            isAllDay: false,
            calendar: draft.calendar,
            availability: draft.availability,
            location: draft.location,
            details: draft.details
        )
        entries.append(event)
        return event
    }

    func update(_ event: ScheduledEvent, with change: EventChange) async throws -> ScheduledEvent {
        guard let index = entries.firstIndex(of: event) else {
            throw CalendarSourceWriteFailure.eventNotFound(source: identifier, title: event.title)
        }
        let changed = ScheduledEvent(
            source: identifier,
            identifier: event.identifier,
            title: change.title ?? event.title,
            interval: change.interval ?? event.interval,
            isAllDay: event.isAllDay,
            calendar: change.calendar ?? event.calendar,
            availability: event.availability,
            location: change.location ?? event.location,
            details: change.details.applied(to: event.details)
        )
        entries[index] = changed
        return changed
    }

    func remove(_ event: ScheduledEvent) async throws {
        guard let index = entries.firstIndex(of: event) else {
            throw CalendarSourceWriteFailure.eventNotFound(source: identifier, title: event.title)
        }
        entries.remove(at: index)
    }
}

/// Booking, changing and removing events: the calendar each write goes to,
/// what it overlaps, offers filled, and what it refuses.
enum SchedulingBookingTests {
    private static let openSlot = F.event("Open slot", "2026-11-23T15:00:00+01:00", "2026-11-23T17:00:00+01:00", calendar: "Slots")

    private static func fixture() throws -> (WritableFixtureSource, ToolContext) {
        let source = WritableFixtureSource(
            entries: F.events + [openSlot],
            calendars: ["Levi", "Anna", "Sam", "Slots", "Cancelled"]
        )
        let base = F.runtime()
        let levi = SchedulingParticipant(
            identifier: "levi",
            name: "Levi",
            timeZone: F.zone,
            calendars: [
                CalendarPolicy("Levi"),
                CalendarPolicy("Slots", role: .offers),
                CalendarPolicy("Cancelled", role: .records),
            ]
        )
        let runtime = Scheduling.Runtime(
            sources: [source],
            participants: [levi] + base.participants.dropFirst(),
            places: base.places,
            defaults: base.defaults
        )
        return (source, try F.context(runtime))
    }

    static func book() async throws {
        let (source, context) = try fixture()
        let book = Scheduling.Tools.Book()

        let clean = try await book.call(
            .init(title: "Intake", start: "2026-11-23T11:00:00+01:00", location: "office"),
            in: context
        )
        try Expect.equal(clean.calendar, "Levi", "Primary participant's commitments calendar")
        try Expect.equal(clean.end, "2026-11-23T12:00:00+01:00", "Configured duration")
        try Expect.equal(clean.overlaps, [], "Nothing in the way")
        try Expect.isNil(clean.removed_offer, "No offer filled unless asked")

        let clash = Scheduling.Tools.Book.Input(title: "Call", start: "2026-11-23T09:30:00+01:00", duration_minutes: 30)
        let preflight = try await book.preflight(clash, in: context)
        try Expect.true(preflight.warnings.contains { $0.contains("Standup") }, "Approval names the overlap")
        guard let section = preflight.preview.sections.first,
              case .report(let card) = section.content,
              case .event(let event)? = card.blocks.first else {
            throw TestFlowAssertionFailure(label: "event card", message: "Book previews an event card")
        }
        try Expect.equal(section.title, "Event", "The approval menu names the preview")
        try Expect.equal(event.change, .create, "A new event")
        try Expect.equal(event.calendar, "Levi", "The calendar it goes into")
        try Expect.true(event.warnings.contains { $0.contains("Standup") }, "The card names the overlap")
        try Expect.true(event.context?.lanes.contains { $0.label == "New" } == true, "The day around it, with the event marked")
        let overlapping = try await book.call(clash, in: context)
        try Expect.true(overlapping.overlaps.contains { $0.contains("Standup") }, "Result names the overlap")
        let shown = try Expect.notNil(book.present(overlapping, input: clash, preflight: preflight), "A booking presents its card")
        guard case .event(let written)? = shown.document.blocks.first else {
            throw TestFlowAssertionFailure(label: "written card", message: "The result is an event card")
        }
        try Expect.equal(shown.placement, .attachment, "Under the answer")
        try Expect.equal(written.title, "Call", "The written title")
        try Expect.notNil(written.context, "The approved day view is kept, not fetched again")
        let unreviewed = try Expect.notNil(book.present(overlapping, input: clash, preflight: nil), "Without a review, a card from the output")
        guard case .event(let plain)? = unreviewed.document.blocks.first else {
            throw TestFlowAssertionFailure(label: "written card", message: "The result is an event card")
        }
        try Expect.isNil(plain.context, "No day view without the review")

        do {
            _ = try await book.call(.init(title: "Joint", start: "2026-11-23T15:00:00+01:00", participants: ["levi", "anna"]), in: context)
            try Expect.true(false, "No shared calendar must throw")
        } catch Scheduling.EventWriteFailure.noDefaultCalendar {}

        let named = try await book.call(
            .init(title: "Joint", start: "2026-11-23T15:00:00+01:00", participants: ["levi", "anna"], calendar: "anna"),
            in: context
        )
        try Expect.equal(named.calendar, "Anna", "Named calendar, by identifier")

        do {
            _ = try await book.call(.init(title: "Note", start: "2026-11-23T15:00:00+01:00", calendar: "Cancelled"), in: context)
            try Expect.true(false, "Booking into a records calendar must throw")
        } catch Scheduling.EventWriteFailure.unbookableRole {}

        let filled = try await book.call(
            .init(title: "Session", start: "2026-11-23T15:30:00+01:00", fill_offer: true),
            in: context
        )
        try Expect.true(filled.removed_offer?.contains("Open slot") == true, "The offer it fills is named")
        let remaining = await source.entries
        try Expect.false(remaining.contains(openSlot), "The offer is removed")
        try Expect.true(remaining.contains { $0.title == "Session" }, "The appointment is written")

        do {
            _ = try await book.call(.init(title: "Late", start: "2026-11-23T18:00:00+01:00", fill_offer: true), in: context)
            try Expect.true(false, "Filling a missing offer must throw")
        } catch Scheduling.EventWriteFailure.noOpenOffer {}

        do {
            _ = try await book.call(.init(title: "Intake", start: "2026-11-23T15:00:00+01:00"), in: try F.context())
            try Expect.true(false, "A read-only source must throw")
        } catch CalendarSourceWriteFailure.readOnly {}
    }

    /// Notes, link, alerts and repetition are written and shown; what the
    /// source cannot store is named before approval and left out.
    static func details() async throws {
        let (source, context) = try fixture()
        let book = Scheduling.Tools.Book()
        let input = Scheduling.Tools.Book.Input(
            title: "Session",
            start: "2026-11-24T11:00:00+01:00",
            notes: "Bring the long line",
            url: "https://example.org/call",
            alerts_minutes_before: [15, 1440, 15],
            travel_minutes: 30,
            attachments: ["plans/intake.pdf"],
            repeats: .init(frequency: .weekly, count: 5)
        )
        let preflight = try await book.preflight(input, in: context)
        guard case .report(let document)? = preflight.preview.sections.first?.content,
              case .event(let card)? = document.blocks.first else {
            throw TestFlowAssertionFailure(label: "event card", message: "Book previews an event card")
        }
        try Expect.equal(card.alerts, [15, 1440], "Alerts once each, soonest first")
        try Expect.equal(card.recurrence, "every week, 5 times", "Repetition in words")
        try Expect.equal(card.url, "https://example.org/call", "The link")
        try Expect.equal(card.notes, "Bring the long line", "The notes")
        try Expect.isNil(card.travelMinutes, "Travel time the source cannot store is not shown as written")
        try Expect.true(card.warnings.contains { $0.contains("travel time") }, "Unstorable travel time is named")
        try Expect.true(card.warnings.contains { $0.contains("attachments") }, "Unstorable attachments are named")

        _ = try await book.call(input, in: context)
        let written = try Expect.notNil(await source.entries.first { $0.title == "Session" }, "Written")
        try Expect.equal(written.details.alerts.map(\.raw), [15, 1440], "Alerts written")
        try Expect.equal(written.details.recurrence?.count, 5, "Repetition written")
        try Expect.isNil(written.details.travel, "Travel time not written")

        let agenda = try await Scheduling.Tools.Agenda().call(
            .init(window_start: "2026-11-24T00:00:00+01:00", window_end: "2026-11-25T00:00:00+01:00"),
            in: context
        )
        let entry = try Expect.notNil(agenda.participants.flatMap(\.entries).first { $0.title == "Session" }, "Listed")
        try Expect.equal(entry.url, "https://example.org/call", "The agenda reads the link back")
        try Expect.equal(entry.alerts_minutes_before, [15, 1440], "and the alerts")

        do {
            _ = try await book.preflight(
                .init(title: "Bad", start: "2026-11-24T15:00:00+01:00", repeats: .init(frequency: .daily, count: 3, until: "2026-12-01T00:00:00+01:00")),
                in: context
            )
            try Expect.true(false, "A count and an end date must throw")
        } catch Scheduling.EventWriteFailure.invalidRecurrence {}

        let update = Scheduling.Tools.Update()
        let cleared = try await update.call(
            .init(event_start: "2026-11-24T11:00:00+01:00", event_title: "Session", alerts_minutes_before: []),
            in: context
        )
        try Expect.equal(cleared.title, "Session", "Changed")
        let after = try Expect.notNil(await source.entries.first { $0.title == "Session" }, "Still there")
        try Expect.equal(after.details.alerts, [], "An empty list clears the alerts")
        try Expect.equal(after.details.notes, "Bring the long line", "Other details kept")
    }

    static func update() async throws {
        let (source, context) = try fixture()
        let update = Scheduling.Tools.Update()

        let moved = Scheduling.Tools.Update.Input(
            event_start: "2026-11-23T13:00:00+01:00",
            event_title: "client visit",
            start: "2026-11-23T16:30:00+01:00"
        )
        let preflight = try await update.preflight(moved, in: context)
        try Expect.true(preflight.summary.contains("Client visit"), "Approval names the event")
        guard case .report(let changed)? = preflight.preview.sections.first?.content,
              case .event(let card)? = changed.blocks.first else {
            throw TestFlowAssertionFailure(label: "event card", message: "Update previews an event card")
        }
        try Expect.equal(card.change, .update, "A changed event")
        try Expect.notNil(card.previous, "Where it was")
        let result = try await update.call(moved, in: context)
        try Expect.equal(result.start, "2026-11-23T16:30:00+01:00", "New start")
        try Expect.equal(result.end, "2026-11-23T17:30:00+01:00", "Length kept")
        try Expect.equal(result.location, "Utrecht client", "Location kept")

        let nudged = try await update.call(
            .init(event_start: "2026-11-23T09:00:00+01:00", event_title: "Standup", start: "2026-11-23T09:15:00+01:00"),
            in: context
        )
        try Expect.equal(nudged.overlaps, [], "The moved event does not overlap itself")

        let cancelled = try await update.call(
            .init(event_start: "2026-11-23T09:15:00+01:00", event_title: "Standup", calendar: "Cancelled"),
            in: context
        )
        try Expect.equal(cancelled.calendar, "Cancelled", "Moved into the records calendar")

        do {
            _ = try await update.call(.init(event_start: "2026-11-23T16:30:00+01:00", event_title: "Client visit"), in: context)
            try Expect.true(false, "An empty change must throw")
        } catch Scheduling.EventWriteFailure.nothingToChange {}

        do {
            _ = try await update.call(.init(event_start: "2026-11-23T13:00:00+01:00", event_title: "Client visit", title: "Gone"), in: context)
            try Expect.true(false, "The old start no longer matches")
        } catch Scheduling.EventWriteFailure.eventNotFound {}

        let entries = await source.entries
        try Expect.equal(entries.filter { $0.title == "Client visit" }.count, 1, "Changed in place, not copied")
    }

    static func remove() async throws {
        let (source, context) = try fixture()
        let remove = Scheduling.Tools.Remove()
        let input = Scheduling.Tools.Remove.Input(event_start: "2026-11-24T15:00:00+01:00", event_title: "Call A")

        let preflight = try await remove.preflight(input, in: context)
        try Expect.true(preflight.summary.contains("Call A"), "Approval names the event")
        let result = try await remove.call(input, in: context)
        try Expect.true(result.removed.contains("Call A"), "Result names the event")

        let entries = await source.entries
        try Expect.false(entries.contains { $0.title == "Call A" }, "Event removed")
        try Expect.true(entries.contains { $0.title == "Call B" }, "Only that event")

        do {
            _ = try await remove.call(input, in: context)
            try Expect.true(false, "Removing twice must throw")
        } catch Scheduling.EventWriteFailure.eventNotFound {}
    }
}
