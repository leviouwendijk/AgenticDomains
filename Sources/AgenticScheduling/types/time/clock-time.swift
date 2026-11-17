import Foundation
import Primitives

/// A wall-clock time of day written `HH:mm`, from `00:00` to `24:00`.
///
/// `24:00` is accepted so a range can run to the end of the day.
public struct ClockTime:
    CodableInvariant,
    Sendable,
    Hashable,
    Comparable
{
    public let raw: String

    /// Minutes after midnight, 0...1440.
    public let minuteOfDay: Int

    public init(_ raw: String) throws(InvarianceFailure) {
        guard let minutes = Self.minutes(raw) else {
            throw InvarianceFailure(InvarianceViolation(InvalidClockTime(value: raw)))
        }
        self.raw = raw
        self.minuteOfDay = minutes
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.minuteOfDay < rhs.minuteOfDay
    }

    private static func minutes(_ raw: String) -> Int? {
        let parts = raw.split(separator: ":", omittingEmptySubsequences: false)
        guard
            parts.count == 2,
            parts[0].count == 2,
            parts[1].count == 2,
            let hours = Int(parts[0]),
            let minutes = Int(parts[1]),
            (0...24).contains(hours),
            (0...59).contains(minutes)
        else {
            return nil
        }
        let total = hours * 60 + minutes
        return total <= 1440 ? total : nil
    }
}

/// A same-day range of wall-clock times with `from` before `to`.
public struct ClockRange:
    MutableInvariant,
    Sendable,
    Hashable
{
    public struct Bounds: Sendable, Hashable {
        public var from: ClockTime
        public var to: ClockTime

        public init(from: ClockTime, to: ClockTime) {
            self.from = from
            self.to = to
        }
    }

    public let raw: Bounds

    public init(_ raw: Bounds) throws(InvarianceFailure) {
        try Invariance<Bounds>([
            .predicate(
                where: { $0.from < $0.to },
                on_failure: { _ in InvarianceViolation(InvertedClockRange()) }
            ),
        ]).require(raw)
        self.raw = raw
    }

    public init(from: String, to: String) throws(InvarianceFailure) {
        try self.init(.init(from: ClockTime(from), to: ClockTime(to)))
    }

    public var from: ClockTime { raw.from }
    public var to: ClockTime { raw.to }
}

private struct InvalidClockTime: InvarianceReason {
    let value: String
    var code: InvarianceCode { .custom("schedule.clock_time.invalid") }
    var message: String { "'\(value)' is not a time of day in HH:mm form (00:00...24:00)." }
}

private struct InvertedClockRange: InvarianceReason {
    let code: InvarianceCode = .custom("schedule.clock_range.inverted")
    let message = "A time-of-day range must start before it ends."
}
