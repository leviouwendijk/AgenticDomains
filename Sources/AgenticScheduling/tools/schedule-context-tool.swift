import Agentic
import Foundation
import Macros
import Schema

public extension Scheduling.Tools {
    @Tool("context")
    struct Context {
        @JSONSchema
        public struct Input: HashableSource {
            public init() {}
        }

        @JSONSchema
        public struct Person: HashableResult {
            public let identifier: String
            public let name: String
            public let about: String?
            public let home: String?
            /// Days with working hours, such as `saturday 10:00-21:00`.
            public let working_hours: [String]
            /// Hours held back by default each week.
            public let reserved_hours: [String]
            /// Calendars that make up this person's time, with their role.
            public let calendars: [String]
        }

        @JSONSchema
        public struct Defaults: HashableResult {
            public let time_zone: String
            public let duration_minutes: Int
            public let overrun_minutes: Int
            public let buffer_minutes: Int
            public let preferred_hours: String?
            public let placement: SlotPlacement
            public let travel_mode: TravelMode
            public let split_travel: SplitTravelPolicy
        }

        @JSONSchema
        public struct Output: HashableResult {
            /// The team's own brief, in their words.
            public let context: String?
            /// The first person is the default when a request names nobody.
            public let participants: [Person]
            public let defaults: Defaults
            public let information_gaps: [String]
        }

        public static let purpose =
            "The team's own brief (who they are, naming conventions, what typical requests mean) with who is who and the scheduling defaults. Read it once at the start of a conversation to interpret requests in their terms."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_: Input, in context: CapabilityContext) async throws -> Output {
            let runtime = try Scheduling.runtime(in: context)
            let defaults = runtime.defaults
            return .init(
                context: runtime.context,
                participants: runtime.participants.map { participant in
                    .init(
                        identifier: participant.identifier,
                        name: participant.name,
                        about: participant.about,
                        home: participant.home,
                        working_hours: Self.week(participant.workingHours),
                        reserved_hours: Self.week(participant.reservedHours),
                        calendars: participant.calendars.map { policy in
                            var traits = [policy.role.rawValue]
                            if let allDay = policy.allDayRole {
                                traits.append("all-day \(allDay.rawValue)")
                            }
                            if policy.sharedTravel {
                                traits.append("shared travel")
                            }
                            return "\(policy.title) (\(traits.joined(separator: ", ")))"
                        }
                    )
                },
                defaults: .init(
                    time_zone: defaults.timeZone.raw,
                    duration_minutes: defaults.duration.raw,
                    overrun_minutes: defaults.overrun.raw,
                    buffer_minutes: defaults.buffer.raw,
                    preferred_hours: defaults.preferredHours.map { "\($0.from.raw)-\($0.to.raw)" },
                    placement: defaults.placement,
                    travel_mode: defaults.travelMode,
                    split_travel: defaults.splitTravel
                ),
                information_gaps: runtime.context == nil
                    ? ["No team context is configured (the `context` field of \(SchedulingFrame.fileName)); interpret requests from the calendars alone."]
                    : []
            )
        }

        private static func week(_ hours: WorkingHours) -> [String] {
            ScheduleWeekday.allCases.flatMap { day in
                hours.ranges(on: day).map { "\(day.rawValue) \($0.from.raw)-\($0.to.raw)" }
            }
        }
    }
}
