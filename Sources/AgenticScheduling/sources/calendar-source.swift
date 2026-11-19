import Foundation
import Macros
import Schema

/// A provider of calendar events: EventKit today, Google and Postgres later.
public protocol CalendarSource: Sendable {
    /// Stable name for this source, such as `apple_calendar`.
    var identifier: String { get }

    func authorization() async -> CalendarSourceAuthorization

    func calendars() async throws -> [CalendarReference]

    /// The details this source can store with an event. A requested detail
    /// outside it is named in the approval and not written. Default: all.
    var storedDetails: Set<EventDetail> { get }

    /// Events overlapping `interval`, from every calendar the source sees.
    func events(in interval: ScheduleInterval) async throws -> [ScheduledEvent]

    /// Writes one new event into a calendar this source shows. Sources
    /// that cannot write throw `CalendarSourceWriteFailure.readOnly`.
    func create(_ draft: EventDraft) async throws -> ScheduledEvent

    /// Changes one occurrence of an event this source returned; fields the
    /// change leaves `nil` stay as they are.
    func update(_ event: ScheduledEvent, with change: EventChange) async throws -> ScheduledEvent

    /// Removes one occurrence of an event this source returned.
    func remove(_ event: ScheduledEvent) async throws
}

public extension CalendarSource {
    var storedDetails: Set<EventDetail> {
        Set(EventDetail.allCases)
    }

    func create(_: EventDraft) async throws -> ScheduledEvent {
        throw CalendarSourceWriteFailure.readOnly(source: identifier)
    }

    func update(_: ScheduledEvent, with _: EventChange) async throws -> ScheduledEvent {
        throw CalendarSourceWriteFailure.readOnly(source: identifier)
    }

    func remove(_: ScheduledEvent) async throws {
        throw CalendarSourceWriteFailure.readOnly(source: identifier)
    }
}

/// What to change on an existing event; `nil` keeps the current value.
public struct EventChange: Sendable, Hashable {
    public let title: String?
    public let interval: ScheduleInterval?
    public let calendar: CalendarReference?
    public let location: String?
    public let details: EventDetailsChange

    public init(
        title: String? = nil,
        interval: ScheduleInterval? = nil,
        calendar: CalendarReference? = nil,
        location: String? = nil,
        details: EventDetailsChange = .init()
    ) {
        self.title = title
        self.interval = interval
        self.calendar = calendar
        self.location = location
        self.details = details
    }

    public var isEmpty: Bool {
        title == nil && interval == nil && calendar == nil && location == nil && details.isEmpty
    }
}

/// A new event, before a source has written it.
public struct EventDraft: Sendable, Hashable {
    public let title: String
    public let interval: ScheduleInterval
    public let calendar: CalendarReference
    public let availability: EventAvailability
    public let location: String?
    public let details: EventDetails

    public init(
        title: String,
        interval: ScheduleInterval,
        calendar: CalendarReference,
        availability: EventAvailability = .busy,
        location: String? = nil,
        details: EventDetails = .none
    ) {
        self.title = title
        self.interval = interval
        self.calendar = calendar
        self.availability = availability
        self.location = location
        self.details = details
    }
}

public enum CalendarSourceWriteFailure: Error, Sendable, LocalizedError {
    case readOnly(source: String)
    case calendarNotFound(source: String, calendar: String)
    case calendarNotWritable(source: String, calendar: String)
    case eventNotFound(source: String, title: String)

    public var errorDescription: String? {
        switch self {
        case .readOnly(let source):
            return "Calendar source \(source) is read-only."
        case .calendarNotFound(let source, let calendar):
            return "Calendar source \(source) has no calendar '\(calendar)'."
        case .calendarNotWritable(let source, let calendar):
            return "Calendar '\(calendar)' in \(source) cannot be changed, such as a subscribed or read-only shared calendar."
        case .eventNotFound(let source, let title):
            return "Calendar source \(source) no longer has the event '\(title)' at that time; it may have been moved or removed."
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
