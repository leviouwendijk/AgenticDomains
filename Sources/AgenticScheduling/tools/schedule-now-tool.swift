import Agentic
import Foundation
import Macros
import Schema

public extension Scheduling.Tools {
    @Tool("schedule_now")
    struct Now {
        @JSONSchema
        public struct Input: HashableSource {
            public init() {}
        }

        @JSONSchema
        public struct Output: HashableResult {
            /// The current moment, ISO 8601 with offset.
            public let now: String
            /// Today's date, `yyyy-MM-dd`.
            public let today: String
            public let weekday: ScheduleWeekday
            public let time_zone: String
            /// Today 00:00 up to the same time seven days later.
            public let coming_week_start: String
            public let coming_week_end: String
            /// Monday 00:00 of this week up to the next Monday.
            public let this_week_start: String
            public let this_week_end: String
        }

        public static let purpose =
            "The current date and time in the configured zone, with the exact windows for the coming seven days and for this week (Monday to Monday). Call it before resolving any relative date; never assume the date."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_: Input, in context: ToolContext) async throws -> Output {
            let runtime = try Scheduling.runtime(in: context)
            return try Self.output(at: Date(), in: runtime.defaults.timeZone)
        }

        public static func output(at now: Date, in zone: ScheduleTimeZone) throws -> Output {
            let calendar = zone.calendar
            let today = calendar.startOfDay(for: now)
            let weekdayIndex = calendar.component(.weekday, from: today)
            // Calendar weekdays run Sunday = 1 ... Saturday = 7.
            let sinceMonday = (weekdayIndex + 5) % 7
            guard
                let comingEnd = calendar.date(byAdding: .day, value: 7, to: today),
                let monday = calendar.date(byAdding: .day, value: -sinceMonday, to: today),
                let nextMonday = calendar.date(byAdding: .day, value: 7, to: monday)
            else {
                throw Scheduling.InputFailure.invalid(field: "now", reason: "the calendar could not compute this week")
            }
            let date = DateFormatter()
            date.calendar = calendar
            date.timeZone = zone.timeZone
            date.locale = Locale(identifier: "en_US_POSIX")
            date.dateFormat = "yyyy-MM-dd"

            return .init(
                now: ScheduleTimestamp.render(now, in: zone),
                today: date.string(from: today),
                weekday: ScheduleWeekday.of(now, in: zone),
                time_zone: zone.raw,
                coming_week_start: ScheduleTimestamp.render(today, in: zone),
                coming_week_end: ScheduleTimestamp.render(comingEnd, in: zone),
                this_week_start: ScheduleTimestamp.render(monday, in: zone),
                this_week_end: ScheduleTimestamp.render(nextMonday, in: zone)
            )
        }
    }
}
