import Foundation
import Macros
import Schema

/// How an event occupies its owner's time, as reported by its source.
@JSONSchema
public enum EventAvailability:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case busy
    case tentative
    case free
    case unavailable

    /// Whether the event blocks other appointments. Tentative events block:
    /// a slot offered over a tentative hold would usually be declined.
    public var blocks: Bool {
        self != .free
    }
}

/// One event from any calendar source, normalised.
public struct ScheduledEvent: Sendable, Hashable {
    public let source: String
    public let identifier: String
    public let title: String
    public let interval: ScheduleInterval
    public let isAllDay: Bool
    public let calendar: CalendarReference
    public let availability: EventAvailability
    public let location: String?

    public init(
        source: String,
        identifier: String,
        title: String,
        interval: ScheduleInterval,
        isAllDay: Bool,
        calendar: CalendarReference,
        availability: EventAvailability,
        location: String?
    ) {
        self.source = source
        self.identifier = identifier
        self.title = title
        self.interval = interval
        self.isAllDay = isAllDay
        self.calendar = calendar
        self.availability = availability
        self.location = location
    }

    public var blocks: Bool {
        availability.blocks
    }

    /// The location text when it carries anything to resolve.
    public var locationText: String? {
        guard let text = location?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        return text
    }
}

/// Which calendar an event belongs to.
public struct CalendarReference: Sendable, Hashable {
    public let identifier: String
    public let title: String

    public init(identifier: String, title: String) {
        self.identifier = identifier
        self.title = title
    }
}
