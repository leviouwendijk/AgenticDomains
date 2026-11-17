import Foundation
import Primitives

/// A non-negative whole number of minutes.
public struct ScheduleMinutes:
    CodableInvariant,
    Sendable,
    Hashable,
    Comparable
{
    public let raw: Int

    public init(_ raw: Int) throws(InvarianceFailure) {
        try Invariance<Int>([
            .predicate(
                where: { $0 >= 0 },
                on_failure: { _ in InvarianceViolation(NegativeMinutes()) }
            ),
        ]).require(raw)
        self.raw = raw
    }

    public static let zero = ScheduleMinutes(preserving: 0)

    private init(preserving raw: Int) {
        self.raw = raw
    }

    public var seconds: TimeInterval { TimeInterval(raw * 60) }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.raw < rhs.raw
    }

    /// Parses an optional raw value, falling back when absent.
    public static func parse(_ raw: Int?, default fallback: ScheduleMinutes) throws -> ScheduleMinutes {
        guard let raw else {
            return fallback
        }
        return try ScheduleMinutes(raw)
    }
}

private struct NegativeMinutes: InvarianceReason {
    let code: InvarianceCode = .custom("schedule.minutes.negative")
    let message = "Minutes must not be negative."
}
