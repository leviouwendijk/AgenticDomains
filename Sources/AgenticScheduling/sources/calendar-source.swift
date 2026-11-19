import Foundation
import Macros
import Schema

/// A provider of calendar events: EventKit today, Google and Postgres later.
public protocol CalendarSource: Sendable {
    /// Stable name for this source, such as `apple_calendar`.
    var identifier: String { get }

    func authorization() async -> CalendarSourceAuthorization

    func calendars() async throws -> [CalendarReference]

    /// Events overlapping `interval`, from every calendar the source sees.
    func events(in interval: ScheduleInterval) async throws -> [ScheduledEvent]

    /// Writes one new event into a calendar this source shows. Sources
    /// that cannot write throw `CalendarSourceWriteFailure.readOnly`.
    func create(_ draft: EventDraft) async throws -> ScheduledEvent
}

public extension CalendarSource {
    func create(_: EventDraft) async throws -> ScheduledEvent {
        throw CalendarSourceWriteFailure.readOnly(source: identifier)
    }
}

/// A new event, before a source has written it.
public struct EventDraft: Sendable, Hashable {
    public let title: String
    public let interval: ScheduleInterval
    public let calendar: CalendarReference
    public let availability: EventAvailability
    public let location: String?
    public let notes: String?

    public init(
        title: String,
        interval: ScheduleInterval,
        calendar: CalendarReference,
        availability: EventAvailability = .busy,
        location: String? = nil,
        notes: String? = nil
    ) {
        self.title = title
        self.interval = interval
        self.calendar = calendar
        self.availability = availability
        self.location = location
        self.notes = notes
    }
}

public enum CalendarSourceWriteFailure: Error, Sendable, LocalizedError {
    case readOnly(source: String)
    case calendarNotFound(source: String, calendar: String)
    case calendarNotWritable(source: String, calendar: String)

    public var errorDescription: String? {
        switch self {
        case .readOnly(let source):
            return "Calendar source \(source) is read-only."
        case .calendarNotFound(let source, let calendar):
            return "Calendar source \(source) has no calendar '\(calendar)'."
        case .calendarNotWritable(let source, let calendar):
            return "Calendar '\(calendar)' in \(source) does not accept new events, such as a subscribed or read-only shared calendar."
        }
    }
}

@JSONSchema
public enum CalendarSourceAuthorization:
    String,
    Sendable,
    Codable,
    Hashable
{
    case authorized
    case not_determined
    case denied
    case restricted
    case unknown
}
