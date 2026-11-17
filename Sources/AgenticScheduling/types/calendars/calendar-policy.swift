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
    /// How all-day events are read when that differs from `role`, as when
    /// a calendar holds timed meetings and all-day office days.
    public let allDayRole: CalendarRole?
    /// How far appointments in this calendar typically run past their
    /// nominal end. A soft margin: it lowers scores and raises warnings,
    /// it never excludes a slot.
    public let overrun: ScheduleMinutes
    /// For an offers calendar: title fragments that mark a slot as still
    /// open, such as `Slot`. An event whose title contains none of them is
    /// a provisional booking and blocks. Empty means every event is open.
    public let offerTitles: [String]
    /// Its participants travel together, in one vehicle: they arrive from
    /// the same place and leave for the same place.
    public let sharedTravel: Bool

    public init(
        _ title: String,
        identifier: String? = nil,
        role: CalendarRole = .commitments,
        allDayRole: CalendarRole? = nil,
        overrun: ScheduleMinutes = .zero,
        offerTitles: [String] = [],
        sharedTravel: Bool = false
    ) {
        self.title = title
        self.identifier = identifier
        self.role = role
        self.allDayRole = allDayRole
        self.overrun = overrun
        self.offerTitles = offerTitles
        self.sharedTravel = sharedTravel
    }

    /// How this event in the calendar is read.
    public func role(of event: ScheduledEvent) -> CalendarRole {
        event.isAllDay ? (allDayRole ?? role) : role
    }

    /// How scheduling reads this event: its calendar's role, the event's own
    /// availability, and for offers whether the slot is still open.
    public func reading(of event: ScheduledEvent) -> AgendaReading {
        switch role(of: event) {
        case .commitments:
            return event.blocks ? .blocking : .marked_free
        case .reserved:
            return .reserved
        case .records:
            return .record
        case .offers:
            let open = offerTitles.isEmpty || offerTitles.contains {
                event.title.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
            return open ? .offer : .provisional
        }
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
