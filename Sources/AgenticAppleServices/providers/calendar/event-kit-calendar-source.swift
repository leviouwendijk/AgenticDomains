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

    /// EventKit keeps no travel time or attachments in its public API.
    public nonisolated var storedDetails: Set<EventDetail> {
        [.notes, .url, .alerts, .recurrence]
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
                location: event.location,
                details: Self.details(event)
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
        event.availability = Self.availability(draft.availability)
        Self.write(draft.details, to: event)
        try eventStore.save(event, span: draft.details.recurrence == nil ? .thisEvent : .futureEvents, commit: true)

        return ScheduledEvent(
            source: identifier,
            identifier: event.eventIdentifier ?? event.calendarItemIdentifier,
            title: draft.title,
            interval: draft.interval,
            isAllDay: false,
            calendar: Self.reference(calendar),
            availability: draft.availability,
            location: draft.location,
            details: Self.details(event)
        )
    }

    public func update(_ event: ScheduledEvent, with change: EventChange) async throws -> ScheduledEvent {
        try await requireAccess()
        let stored = try occurrence(of: event)
        if let target = change.calendar {
            guard let calendar = eventStore.calendar(withIdentifier: target.identifier) else {
                throw CalendarSourceWriteFailure.calendarNotFound(source: identifier, calendar: target.title)
            }
            guard calendar.allowsContentModifications else {
                throw CalendarSourceWriteFailure.calendarNotWritable(source: identifier, calendar: calendar.title)
            }
            stored.calendar = calendar
        }
        if let title = change.title {
            stored.title = title
        }
        if let interval = change.interval {
            stored.startDate = interval.start
            stored.endDate = interval.end
        }
        if let location = change.location {
            stored.location = location
        }
        if let notes = change.details.notes {
            stored.notes = notes
        }
        if let url = change.details.url {
            stored.url = url
        }
        if let alerts = change.details.alerts {
            stored.alarms = alerts.map { EKAlarm(relativeOffset: -$0.seconds) }
        }
        try eventStore.save(stored, span: .thisEvent, commit: true)

        return ScheduledEvent(
            source: identifier,
            identifier: stored.eventIdentifier ?? stored.calendarItemIdentifier,
            title: stored.title ?? "",
            interval: change.interval ?? event.interval,
            isAllDay: stored.isAllDay,
            calendar: Self.reference(stored.calendar),
            availability: Self.availability(stored),
            location: stored.location,
            details: Self.details(stored)
        )
    }

    public func remove(_ event: ScheduledEvent) async throws {
        try await requireAccess()
        let stored = try occurrence(of: event)
        try eventStore.remove(stored, span: .thisEvent, commit: true)
    }

    /// The stored occurrence `event` was read from. The identifier is shared
    /// by every occurrence of a recurring event, so its start picks the one.
    private func occurrence(of event: ScheduledEvent) throws -> EKEvent {
        let calendars = eventStore.calendar(withIdentifier: event.calendar.identifier).map { [$0] }
        let predicate = eventStore.predicateForEvents(
            withStart: event.interval.start,
            end: event.interval.end,
            calendars: calendars
        )
        let match = eventStore.events(matching: predicate).first { stored in
            (stored.eventIdentifier ?? stored.calendarItemIdentifier) == event.identifier
                && stored.startDate == event.interval.start
        }
        guard let match else {
            throw CalendarSourceWriteFailure.eventNotFound(source: identifier, title: event.title)
        }
        guard match.calendar.allowsContentModifications else {
            throw CalendarSourceWriteFailure.calendarNotWritable(source: identifier, calendar: match.calendar.title)
        }
        return match
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

    /// Notes, link, relative alerts and the first repetition rule. Alerts
    /// at a fixed date are left out: they say nothing relative to the event.
    private static func details(_ event: EKEvent) -> EventDetails {
        let alerts = (event.alarms ?? []).compactMap { alarm -> ScheduleMinutes? in
            guard alarm.absoluteDate == nil, alarm.relativeOffset <= 0 else { return nil }
            return try? ScheduleMinutes(Int((-alarm.relativeOffset / 60).rounded()))
        }
        return EventDetails(
            notes: event.notes.flatMap { $0.isEmpty ? nil : $0 },
            url: event.url,
            alerts: alerts.sorted(),
            recurrence: event.recurrenceRules?.first.flatMap(recurrence)
        )
    }

    private static func recurrence(_ rule: EKRecurrenceRule) -> EventRecurrence? {
        let frequency: EventRecurrence.Frequency
        switch rule.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        @unknown default: return nil
        }
        let end = rule.recurrenceEnd
        return EventRecurrence(
            frequency: frequency,
            interval: rule.interval == 1 ? nil : rule.interval,
            count: end.flatMap { $0.occurrenceCount > 0 ? $0.occurrenceCount : nil },
            until: end?.endDate.map { ISO8601DateFormatter().string(from: $0) }
        )
    }

    private static func write(_ details: EventDetails, to event: EKEvent) {
        event.notes = details.notes
        event.url = details.url
        event.alarms = details.alerts.isEmpty ? nil : details.alerts.map { EKAlarm(relativeOffset: -$0.seconds) }
        guard let recurrence = details.recurrence else { return }
        let frequency: EKRecurrenceFrequency
        switch recurrence.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        }
        var end: EKRecurrenceEnd?
        if let count = recurrence.count {
            end = EKRecurrenceEnd(occurrenceCount: count)
        } else if let until = recurrence.until, let date = try? ScheduleTimestamp.parse(until, field: "until") {
            end = EKRecurrenceEnd(end: date)
        }
        event.recurrenceRules = [
            EKRecurrenceRule(recurrenceWith: frequency, interval: recurrence.interval ?? 1, end: end),
        ]
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
