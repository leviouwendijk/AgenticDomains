import Foundation
import Primitives

/// A half-open time interval `[start, end)` whose end lies after its start.
public struct ScheduleInterval:
    MutableInvariant,
    Sendable,
    Hashable
{
    public struct Bounds: Sendable, Hashable {
        public var start: Date
        public var end: Date

        public init(start: Date, end: Date) {
            self.start = start
            self.end = end
        }
    }

    public let raw: Bounds

    public init(_ raw: Bounds) throws(InvarianceFailure) {
        try Invariance<Bounds>([
            .predicate(
                where: { $0.end > $0.start },
                on_failure: { _ in InvarianceViolation(IntervalNotPositive()) }
            ),
        ]).require(raw)
        self.raw = raw
    }

    public init(start: Date, end: Date) throws(InvarianceFailure) {
        try self.init(.init(start: start, end: end))
    }

    /// Only for derivations that provably keep `end > start`.
    private init(preserving raw: Bounds) {
        self.raw = raw
    }

    public var start: Date { raw.start }
    public var end: Date { raw.end }
    public var seconds: TimeInterval { end.timeIntervalSince(start) }
    public var minutes: Int { Int((seconds / 60).rounded(.down)) }

    public func overlaps(_ other: ScheduleInterval) -> Bool {
        start < other.end && other.start < end
    }

    public func contains(_ other: ScheduleInterval) -> Bool {
        start <= other.start && other.end <= end
    }

    /// Widens the interval; non-negative padding keeps it positive.
    public func padded(before: ScheduleMinutes, after: ScheduleMinutes) -> ScheduleInterval {
        .init(
            preserving: .init(
                start: start.addingTimeInterval(-before.seconds),
                end: end.addingTimeInterval(after.seconds)
            )
        )
    }

    /// Merges overlapping or touching intervals into a sorted, disjoint list.
    public static func merged(_ intervals: [ScheduleInterval]) -> [ScheduleInterval] {
        var result: [ScheduleInterval] = []
        for interval in intervals.sorted(by: { $0.start < $1.start }) {
            if let last = result.last, interval.start <= last.end {
                result[result.count - 1] = .init(
                    preserving: .init(start: last.start, end: max(last.end, interval.end))
                )
            } else {
                result.append(interval)
            }
        }
        return result
    }
}

private struct IntervalNotPositive: InvarianceReason {
    let code: InvarianceCode = .custom("schedule.interval.not_positive")
    let message = "An interval must end after it starts."
}
