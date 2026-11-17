import Agentic
import AgenticScheduling
import Foundation

/// A calendar source over a fixed list of events.
struct FixtureCalendarSource: CalendarSource {
    let identifier = "fixture"
    let entries: [ScheduledEvent]

    func authorization() async -> CalendarSourceAuthorization {
        .authorized
    }

    func calendars() async throws -> [CalendarReference] {
        var seen: [CalendarReference] = []
        for event in entries where !seen.contains(event.calendar) {
            seen.append(event.calendar)
        }
        return seen
    }

    func events(in interval: ScheduleInterval) async throws -> [ScheduledEvent] {
        entries.filter { $0.interval.overlaps(interval) }
    }
}

/// Amsterdam team on Monday 2026-11-23 and Tuesday 2026-11-24 (CET, +01:00).
enum SchedulingFixture {
    static let zone = try! ScheduleTimeZone("Europe/Amsterdam")

    static let office = SchedulingPlace(label: "Office", latitude: 52.3676, longitude: 4.9041)
    static let client = SchedulingPlace(label: "Utrecht client", latitude: 52.0907, longitude: 5.1214)

    static func date(_ value: String) -> Date {
        try! ScheduleTimestamp.parse(value, field: "fixture")
    }

    static func event(
        _ title: String,
        _ start: String,
        _ end: String,
        calendar: String,
        availability: EventAvailability = .busy,
        allDay: Bool = false,
        location: String? = nil
    ) -> ScheduledEvent {
        ScheduledEvent(
            source: "fixture",
            identifier: "\(calendar).\(title)",
            title: title,
            interval: try! ScheduleInterval(start: date(start), end: date(end)),
            isAllDay: allDay,
            calendar: .init(identifier: calendar.lowercased(), title: calendar),
            availability: availability,
            location: location
        )
    }

    static let events: [ScheduledEvent] = [
        // Monday
        event("Standup", "2026-11-23T09:00:00+01:00", "2026-11-23T10:00:00+01:00", calendar: "Levi"),
        event("Client visit", "2026-11-23T13:00:00+01:00", "2026-11-23T14:00:00+01:00", calendar: "Levi", location: "Utrecht client"),
        event("Holiday", "2026-11-23T00:00:00+01:00", "2026-11-24T00:00:00+01:00", calendar: "Levi", availability: .free, allDay: true),
        event("Anna focus", "2026-11-23T10:00:00+01:00", "2026-11-23T11:00:00+01:00", calendar: "Anna"),
        event("Sam review", "2026-11-23T11:00:00+01:00", "2026-11-23T12:00:00+01:00", calendar: "Sam"),
        // Tuesday
        event("Lunch", "2026-11-24T12:15:00+01:00", "2026-11-24T12:45:00+01:00", calendar: "Levi", location: "office"),
        event("Workshop", "2026-11-24T13:00:00+01:00", "2026-11-24T14:00:00+01:00", calendar: "Levi", location: "Utrecht client"),
        event("Call A", "2026-11-24T15:00:00+01:00", "2026-11-24T16:00:00+01:00", calendar: "Levi"),
        event("Call B", "2026-11-24T15:30:00+01:00", "2026-11-24T16:30:00+01:00", calendar: "Levi"),
        event("Tentative hold", "2026-11-24T09:00:00+01:00", "2026-11-24T09:30:00+01:00", calendar: "Levi", availability: .tentative),
    ]

    static func runtime(extraParticipants: [SchedulingParticipant] = []) -> Scheduling.Runtime {
        Scheduling.Runtime(
            sources: [FixtureCalendarSource(entries: events)],
            participants: [
                .init(identifier: "levi", name: "Levi", timeZone: zone, calendars: ["Levi"]),
                .init(identifier: "anna", name: "Anna", timeZone: zone, calendars: ["Anna"]),
                .init(identifier: "sam", name: "Sam", timeZone: zone, calendars: ["Sam"]),
            ] + extraParticipants,
            places: StaticPlaceResolver([
                (office, ["office", "kantoor"]),
                (client, []),
            ]),
            defaults: .init(timeZone: zone)
        )
    }

    static func context(_ runtime: Scheduling.Runtime = runtime()) throws -> ToolContext {
        ToolContext(services: try ToolServices().inserting(runtime))
    }

    static let monday = (start: "2026-11-23T00:00:00+01:00", end: "2026-11-24T00:00:00+01:00")
    static let tuesday = (start: "2026-11-24T00:00:00+01:00", end: "2026-11-25T00:00:00+01:00")
}
