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

/// How to read one calendar. Calendars without a policy are commitments.
public struct CalendarPolicy: Sendable, Hashable {
    /// Calendar identifier or title.
    public let calendar: String
    public let role: CalendarRole
    /// How far appointments in this calendar typically run past their
    /// nominal end. A soft margin: it lowers scores and raises warnings,
    /// it never excludes a slot.
    public let overrun: ScheduleMinutes

    public init(
        _ calendar: String,
        role: CalendarRole = .commitments,
        overrun: ScheduleMinutes = .zero
    ) {
        self.calendar = calendar
        self.role = role
        self.overrun = overrun
    }

    func names(_ name: String) -> Bool {
        calendar.caseInsensitiveCompare(name) == .orderedSame
    }
}
