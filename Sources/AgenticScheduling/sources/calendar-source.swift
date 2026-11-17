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
