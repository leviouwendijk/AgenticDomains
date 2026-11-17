import Foundation
import Primitives

/// A time zone known to the system, by IANA identifier.
public struct ScheduleTimeZone:
    CodableInvariant,
    Sendable,
    Hashable
{
    public let raw: String

    public init(_ raw: String) throws(InvarianceFailure) {
        guard TimeZone(identifier: raw) != nil else {
            throw InvarianceFailure(InvarianceViolation(UnknownTimeZone(value: raw)))
        }
        self.raw = raw
    }

    public var timeZone: TimeZone {
        // Validated at construction.
        TimeZone(identifier: raw) ?? .gmt
    }

    /// A Gregorian calendar in this zone, for weekday and time-of-day math.
    public var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// The system's current zone; its identifier is known by definition.
    public static func current() -> ScheduleTimeZone {
        .init(preserving: TimeZone.current.identifier)
    }

    private init(preserving raw: String) {
        self.raw = raw
    }
}

private struct UnknownTimeZone: InvarianceReason {
    let value: String
    var code: InvarianceCode { .custom("schedule.time_zone.unknown") }
    var message: String { "'\(value)' is not a known IANA time zone identifier." }
}
