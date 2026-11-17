import Agentic
import Foundation
import Macros
import Schema

/// How scheduling reads one event, from its calendar's role and its own
/// availability.
@JSONSchema
public enum AgendaReading:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    /// A commitment that occupies time.
    case blocking
    /// In a commitments calendar but marked free: does not block.
    case marked_free
    /// In an offers calendar but no longer titled as an open slot: a
    /// provisional booking. Blocks.
    case provisional
    /// Held back; opened by escalation or an offered slot.
    case reserved
    /// An offered slot, open for booking.
    case offer
    /// A record such as a cancellation; ignored for availability.
    case record
}

public extension Scheduling.Tools {
    @Tool("schedule_agenda")
    struct Agenda {
        @JSONSchema
        public struct Input: HashableSource {
            /// Inclusive window start, ISO 8601 with offset.
            public let window_start: String
            /// Exclusive window end, ISO 8601 with offset.
            public let window_end: String
            /// Participants (identifier or name). Defaults to everyone.
            public let participants: [String]?
            /// Also list records, such as cancellations and birthdays. Default
            /// false: they never affect availability.
            public let include_records: Bool?

            public init(
                window_start: String,
                window_end: String,
                participants: [String]? = nil,
                include_records: Bool? = nil
            ) {
                self.window_start = window_start
                self.window_end = window_end
                self.participants = participants
                self.include_records = include_records
            }
        }

        @JSONSchema
        public struct Entry: HashableResult {
            public let start: String
            public let end: String
            public let title: String
            public let calendar: String
            public let all_day: Bool
            public let reading: AgendaReading
            public let location: String?
        }

        @JSONSchema
        public struct ParticipantAgenda: HashableResult {
            public let participant: String
            public let time_zone: String
            /// Events in time order, as scheduling reads them, with the weekly
            /// reserved hours as `reserved` entries in the calendar
            /// `(reserved hours)`.
            public let entries: [Entry]
            /// Weekly reserved hours on the days in the window, such as
            /// `tuesday 10:00-21:00`.
            public let reserved_hours: [String]
            /// Entries left out because the window held more than the limit.
            public let omitted: Int
            /// Records left out; ask with `include_records` to see them.
            public let hidden_records: Int
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let window_start: String
            public let window_end: String
            public let participants: [ParticipantAgenda]
            public let information_gaps: [String]
        }

        /// The calendar named on entries that stand for weekly reserved hours.
        public static let reservedHoursCalendar = "(reserved hours)"

        /// Entries returned per participant at most.
        public static let limit = 150

        public static let purpose =
            "List each participant's events in a window with time, title, calendar, location and how scheduling reads them (\(AgendaReading.allCases.map(\.rawValue).joined(separator: ", "))), plus their weekly reserved hours. Records are left out unless asked for. Use it to see what a day or week actually holds."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let runtime = try Scheduling.runtime(in: context)
            let window = try ScheduleTimestamp.window(start: input.window_start, end: input.window_end)
            let participants = (input.participants ?? []).isEmpty
                ? runtime.participants
                : try runtime.participants(input.participants)
            let events = try await runtime.events(in: window)
            var gaps: [String] = []

            let agendas = participants.map { participant in
                let zone = participant.timeZone
                let owned = events.filter { participant.owns($0) }
                let all = owned.map { event in
                    Entry(
                        start: ScheduleTimestamp.render(event.interval.start, in: zone),
                        end: ScheduleTimestamp.render(event.interval.end, in: zone),
                        title: event.title,
                        calendar: event.calendar.title,
                        all_day: event.isAllDay,
                        reading: runtime.policy(for: event.calendar).reading(of: event),
                        location: event.locationText
                    )
                }
                let unlocated = zip(owned, all)
                    .filter { !$0.0.isAllDay && [.blocking, .provisional].contains($0.1.reading) && $0.0.locationText == nil }
                    .count
                // Reserved hours are time too: shown as entries, so a
                // timeline of the agenda shows them without retyping.
                let reservedHours = participant.reservedIntervals(in: window).map { interval in
                    Entry(
                        start: ScheduleTimestamp.render(interval.start, in: zone),
                        end: ScheduleTimestamp.render(interval.end, in: zone),
                        title: "reserved hours",
                        calendar: Self.reservedHoursCalendar,
                        all_day: false,
                        reading: .reserved,
                        location: nil
                    )
                }
                let events = input.include_records == true ? all : all.filter { $0.reading != .record }
                let entries = (events + reservedHours).sorted {
                    ((try? ScheduleTimestamp.parse($0.start, field: "start")) ?? .distantPast) < ((try? ScheduleTimestamp.parse($1.start, field: "start")) ?? .distantPast)
                }
                if unlocated > 0 {
                    gaps.append("\(unlocated) of \(participant.identifier)'s timed commitments have no location; travel around them cannot be checked.")
                }
                return ParticipantAgenda(
                    participant: participant.identifier,
                    time_zone: zone.raw,
                    entries: Array(entries.prefix(Self.limit)),
                    reserved_hours: Self.reservedHours(participant, in: window),
                    omitted: max(entries.count - Self.limit, 0),
                    hidden_records: all.count - events.count
                )
            }

            return .init(
                window_start: input.window_start,
                window_end: input.window_end,
                participants: agendas,
                information_gaps: gaps
            )
        }

        /// The participant's reserved hours on each weekday the window touches.
        static func reservedHours(_ participant: SchedulingParticipant, in window: ScheduleInterval) -> [String] {
            let calendar = participant.timeZone.calendar
            var days: [ScheduleWeekday] = []
            var day = calendar.startOfDay(for: window.start)
            while day < window.end, days.count < 7 {
                let weekday = ScheduleWeekday.of(day, in: participant.timeZone)
                if !days.contains(weekday) {
                    days.append(weekday)
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else {
                    break
                }
                day = next
            }
            return days.flatMap { weekday in
                participant.reservedHours.ranges(on: weekday).map {
                    "\(weekday.rawValue) \($0.from.raw)-\($0.to.raw)"
                }
            }
        }
    }
}
