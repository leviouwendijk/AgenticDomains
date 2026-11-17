import Agentic
import Macros
import Schema

public extension Scheduling.Tools {
    @Tool("schedule_calendars")
    struct ListCalendars {
        @JSONSchema
        public struct Input: HashableSource {
            public init() {}
        }

        @JSONSchema
        public struct CalendarSummary: HashableResult {
            public let identifier: String
            public let title: String
            /// How the calendar's events are read.
            public let role: CalendarRole
            /// Usual overrun of its appointments, in minutes.
            public let overrun_minutes: Int
            /// Participants whose time this calendar represents.
            public let participants: [String]
        }

        @JSONSchema
        public struct SourceSummary: HashableResult {
            public let source: String
            public let authorization: CalendarSourceAuthorization
            public let calendars: [CalendarSummary]
        }

        @JSONSchema
        public struct ParticipantSummary: HashableResult {
            public let identifier: String
            public let name: String
            public let time_zone: String
            /// Configured calendar names; empty means every calendar.
            public let calendars: [String]
            /// Working hours per weekday, such as `monday 09:00-17:00`.
            public let working_hours: [String]
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let sources: [SourceSummary]
            /// The first participant is the default for requests naming nobody.
            public let participants: [ParticipantSummary]
            public let information_gaps: [String]
        }

        public static let purpose =
            "List the calendar sources and calendars the scheduler can see, each calendar's role (\(CalendarRole.allCases.map(\.rawValue).joined(separator: ", "))) and usual overrun, who it represents, and each participant's zone and working hours. Use it to know whose time is actually visible and how to read it."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_: Input, in context: ToolContext) async throws -> Output {
            let runtime = try context.require(Scheduling.Runtime.self)
            var gaps: [String] = []
            var sources: [SourceSummary] = []
            var seen: [CalendarReference] = []

            for source in runtime.sources {
                let authorization = await source.authorization()
                var calendars: [CalendarReference] = []
                if authorization == .authorized {
                    calendars = try await source.calendars()
                } else {
                    gaps.append("Source \(source.identifier) is not authorized (\(authorization.rawValue)); its events are invisible.")
                }
                seen += calendars
                sources.append(.init(
                    source: source.identifier,
                    authorization: authorization,
                    calendars: calendars.map { calendar in
                        let policy = runtime.policy(for: calendar)
                        return .init(
                            identifier: calendar.identifier,
                            title: calendar.title,
                            role: policy.role,
                            overrun_minutes: policy.overrun.raw,
                            participants: runtime.participants
                                .filter { $0.calendars.isEmpty || $0.calendars.contains(where: calendar.matches) }
                                .map(\.identifier)
                        )
                    }
                ))
            }

            for policy in runtime.calendars where !seen.contains(where: { $0.matches(policy.calendar) }) {
                gaps.append("Calendar '\(policy.calendar)' has a \(policy.role.rawValue) policy but is not visible in any source.")
            }

            for participant in runtime.participants {
                for name in participant.calendars where !seen.contains(where: { $0.matches(name) }) {
                    gaps.append("Calendar '\(name)' configured for \(participant.identifier) is not visible in any source; their busy time is incomplete.")
                }
            }

            return .init(
                sources: sources,
                participants: runtime.participants.map { participant in
                    .init(
                        identifier: participant.identifier,
                        name: participant.name,
                        time_zone: participant.timeZone.raw,
                        calendars: participant.calendars,
                        working_hours: ScheduleWeekday.allCases.flatMap { day in
                            participant.workingHours.ranges(on: day).map { "\(day.rawValue) \($0.from.raw)-\($0.to.raw)" }
                        }
                    )
                },
                information_gaps: gaps
            )
        }
    }
}
