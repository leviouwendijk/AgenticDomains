import AgenticScheduling
import EventKit
import Foundation

/// Apple Calendar as a scheduling source: every event calendar this Mac's
/// account sees, including subscribed and shared ones.
///
/// Access is requested on first use. Without it EventKit returns no events
/// at all, which would make everyone look free, so reads throw instead.
public actor EventKitCalendarSource:
    CalendarSource
{
    public nonisolated let identifier: String
    private let eventStore: EKEventStore

    public init(
        identifier: String = "apple_calendar",
        eventStore: EKEventStore = .init()
    ) {
        self.identifier = identifier
        self.eventStore = eventStore
    }

    public func authorization() -> CalendarSourceAuthorization {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            switch status {
            case .fullAccess, .authorized:
                return .authorized
            case .writeOnly, .denied:
                return .denied
            case .notDetermined:
                return .not_determined
            case .restricted:
                return .restricted
            @unknown default:
                return .unknown
            }
        }
        switch status {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .not_determined
        case .restricted:
            return .restricted
        default:
            return .unknown
        }
    }

    public func calendars() async throws -> [CalendarReference] {
        try await requireAccess()
        return eventStore.calendars(for: .event).map(Self.reference)
    }

    public func events(in interval: ScheduleInterval) async throws -> [ScheduledEvent] {
        try await requireAccess()
        let predicate = eventStore.predicateForEvents(
            withStart: interval.start,
            end: interval.end,
            calendars: nil
        )
        return eventStore.events(matching: predicate).compactMap { event in
            guard
                let start = event.startDate,
                let end = event.endDate,
                let span = try? ScheduleInterval(start: start, end: end)
            else {
                return nil
            }
            return ScheduledEvent(
                source: identifier,
                identifier: event.eventIdentifier ?? event.calendarItemIdentifier,
                title: event.title ?? "",
                interval: span,
                isAllDay: event.isAllDay,
                calendar: Self.reference(event.calendar),
                availability: Self.availability(event),
                location: event.location
            )
        }
    }

    public func create(_ draft: EventDraft) async throws -> ScheduledEvent {
        try await requireAccess()
        guard let calendar = eventStore.calendar(withIdentifier: draft.calendar.identifier) else {
            throw CalendarSourceWriteFailure.calendarNotFound(source: identifier, calendar: draft.calendar.title)
        }
        guard calendar.allowsContentModifications else {
            throw CalendarSourceWriteFailure.calendarNotWritable(source: identifier, calendar: calendar.title)
        }

        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = draft.title
        event.startDate = draft.interval.start
        event.endDate = draft.interval.end
        event.location = draft.location
        event.notes = draft.notes
        event.availability = Self.availability(draft.availability)
        try eventStore.save(event, span: .thisEvent, commit: true)

        return ScheduledEvent(
            source: identifier,
            identifier: event.eventIdentifier ?? event.calendarItemIdentifier,
            title: draft.title,
            interval: draft.interval,
            isAllDay: false,
            calendar: Self.reference(calendar),
            availability: draft.availability,
            location: draft.location
        )
    }

    private func requireAccess() async throws {
        if authorization() == .not_determined, #available(macOS 14.0, *) {
            _ = try? await eventStore.requestFullAccessToEvents()
        }
        let status = authorization()
        guard status == .authorized else {
            throw EventKitCalendarSourceError.notAuthorized(source: identifier, status: status)
        }
    }

    private static func reference(_ calendar: EKCalendar) -> CalendarReference {
        .init(identifier: calendar.calendarIdentifier, title: calendar.title)
    }

    /// Calendars without availability support report `.notSupported`; then
    /// timed events block and all-day events (holidays, birthdays) do not.
    private static func availability(_ event: EKEvent) -> EventAvailability {
        switch event.availability {
        case .busy:
            return .busy
        case .free:
            return .free
        case .tentative:
            return .tentative
        case .unavailable:
            return .unavailable
        case .notSupported:
            return event.isAllDay ? .free : .busy
        @unknown default:
            return event.isAllDay ? .free : .busy
        }
    }

    private static func availability(_ availability: EventAvailability) -> EKEventAvailability {
        switch availability {
        case .busy:
            return .busy
        case .free:
            return .free
        case .tentative:
            return .tentative
        case .unavailable:
            return .unavailable
        }
    }
}

public enum EventKitCalendarSourceError: Error, Sendable, LocalizedError {
    case notAuthorized(source: String, status: CalendarSourceAuthorization)

    public var errorDescription: String? {
        switch self {
        case .notAuthorized(let source, let status):
            return "Calendar source \(source) has no full calendar access (\(status.rawValue)). Grant it in System Settings > Privacy & Security > Calendars."
        }
    }
}
