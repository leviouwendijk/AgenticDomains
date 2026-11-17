import Foundation
import Macros
import Schema

/// What a calendar's events mean for scheduling. The presence of an event
/// is not by itself a decision about availability; the role says how to
/// read it.
@JSONSchema
public enum CalendarRole:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    /// Appointments that occupy time, as far as each event's own
    /// availability says so (an event marked free does not block).
    case commitments
    /// Open slots offered for booking. They never block; placing an
    /// appointment inside one is preferred or required.
    case offers
    /// Time held back (internal days, admin). Blocks by default; may be
    /// opened as an escalation when nothing else fits.
    case reserved
    /// History or notes, such as cancellations. Never blocks, never offers.
    case records
}

/// A calendar and how to read it. Calendars nobody configured are
/// commitments.
public struct CalendarPolicy: Sendable, Hashable {
    /// The calendar's title as the source shows it.
    public let title: String
    /// The source's identifier, when pinned; then it alone decides the
    /// match, so renaming the calendar does not break it.
    public let identifier: String?
    public let role: CalendarRole
    /// How far appointments in this calendar typically run past their
    /// nominal end. A soft margin: it lowers scores and raises warnings,
    /// it never excludes a slot.
    public let overrun: ScheduleMinutes

    public init(
        _ title: String,
        identifier: String? = nil,
        role: CalendarRole = .commitments,
        overrun: ScheduleMinutes = .zero
    ) {
        self.title = title
        self.identifier = identifier
        self.role = role
        self.overrun = overrun
    }

    public func matches(_ calendar: CalendarReference) -> Bool {
        if let identifier {
            return calendar.identifier == identifier
        }
        return calendar.title.caseInsensitiveCompare(title) == .orderedSame
    }

    /// Whether two policies describe the same calendar.
    func describesSameCalendar(as other: CalendarPolicy) -> Bool {
        if let identifier, let otherIdentifier = other.identifier {
            return identifier == otherIdentifier
        }
        return title.caseInsensitiveCompare(other.title) == .orderedSame
    }

    /// How the calendar is named in messages.
    public var label: String {
        identifier.map { "\(title) (\($0))" } ?? title
    }
}
