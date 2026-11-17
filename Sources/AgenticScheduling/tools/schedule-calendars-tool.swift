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
            /// Configured calendars; empty means every calendar.
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
            let runtime = try Scheduling.runtime(in: context)
            var gaps: [String] = []
            var sources: [SourceSummary] = []
            var seen: [CalendarReference] = []

            var everySourceRead = true
            for source in runtime.sources {
                // Reading is what asks for access on first use, so try it
                // unless access was already refused.
                var calendars: [CalendarReference] = []
                var failed = false
                if await source.authorization() != .denied {
                    do {
                        calendars = try await source.calendars()
                    } catch {
                        failed = true
                        everySourceRead = false
                        gaps.append(error.localizedDescription)
                    }
                }
                let authorization = await source.authorization()
                if authorization != .authorized, !failed {
                    everySourceRead = false
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
                                .filter { $0.calendars.isEmpty || $0.calendars.contains { $0.matches(calendar) } }
                                .map(\.identifier)
                        )
                    }
                ))
            }

            // A missing calendar only means something once every source was read.
            for policy in runtime.calendars where everySourceRead && !seen.contains(where: policy.matches) {
                let owners = runtime.participants
                    .filter { $0.calendars.contains { $0.describesSameCalendar(as: policy) } }
                    .map(\.identifier)
                let usage = owners.isEmpty ? "" : " for \(owners.joined(separator: ", "))"
                gaps.append("Calendar '\(policy.label)' (\(policy.role.rawValue))\(usage) is not visible in any source; what it holds is missing.")
            }

            return .init(
                sources: sources,
                participants: runtime.participants.map { participant in
                    .init(
                        identifier: participant.identifier,
                        name: participant.name,
                        time_zone: participant.timeZone.raw,
                        calendars: participant.calendars.map(\.label),
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
