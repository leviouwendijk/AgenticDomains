import Agentic
import Foundation
import Macros
import Schema

public extension Scheduling.Tools {
    /// Writes one appointment into a calendar. The only scheduling tool that
    /// changes a calendar; the user approves it from its preflight, which
    /// names the calendar and what the appointment would overlap.
    @Tool("schedule_book")
    struct Book {
        @JSONSchema
        public struct Input: HashableSource {
            /// The event's title, as the calendar should show it.
            public let title: String
            /// Start, ISO 8601 with offset, taken from a search, evaluation
            /// or proposal.
            public let start: String
            /// Length in minutes. Defaults to the configured duration.
            public let duration_minutes: Int?
            /// Participants the appointment is for, by identifier or name.
            /// Defaults to the primary participant.
            public let participants: [String]?
            /// Calendar title to write into. Defaults to the one
            /// commitments calendar all participants share.
            public let calendar: String?
            /// Location text, such as the client's address.
            public let location: String?
            public let notes: String?

            public init(
                title: String,
                start: String,
                duration_minutes: Int? = nil,
                participants: [String]? = nil,
                calendar: String? = nil,
                location: String? = nil,
                notes: String? = nil
            ) {
                self.title = title
                self.start = start
                self.duration_minutes = duration_minutes
                self.participants = participants
                self.calendar = calendar
                self.location = location
                self.notes = notes
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let source: String
            /// The event's identifier in its source.
            public let identifier: String
            public let title: String
            public let calendar: String
            public let start: String
            public let end: String
            public let location: String?
            /// Existing events and reserved hours the appointment overlaps,
            /// as approved by the user.
            public let overlaps: [String]
        }

        public enum Failure: Error, Sendable, LocalizedError {
            case emptyTitle
            case unknownCalendar(String, known: [String])
            case ambiguousCalendar(String, sources: [String])
            case noDefaultCalendar(participants: [String], candidates: [String])
            case unbookableRole(calendar: String, role: CalendarRole)

            public var errorDescription: String? {
                switch self {
                case .emptyTitle:
                    return "An appointment needs a title."
                case .unknownCalendar(let name, let known):
                    return "No calendar source shows a calendar '\(name)'. Known: \(known.joined(separator: ", "))."
                case .ambiguousCalendar(let name, let sources):
                    return "Calendar '\(name)' exists in several sources (\(sources.joined(separator: ", "))); name it by identifier."
                case .noDefaultCalendar(let participants, let candidates):
                    let options = candidates.isEmpty ? "none is configured" : "candidates: \(candidates.joined(separator: ", "))"
                    return "No single commitments calendar is shared by \(participants.joined(separator: ", ")) (\(options)). Name the calendar."
                case .unbookableRole(let calendar, let role):
                    return "Calendar '\(calendar)' is a \(role.rawValue) calendar; appointments go into a \(CalendarRole.commitments.rawValue) calendar."
                }
            }
        }

        public static let purpose =
            "Create one appointment in a calendar, after the user has agreed to a time. Writes into the participants' shared commitments calendar unless a calendar is named. It does not remove an offered slot it fills."
        public static let risk: ActionRisk = .boundedmutate

        public init() {}

        public func preflight(_ input: Input, in context: ToolContext) async throws -> ToolPreflight {
            let plan = try await Plan(input, runtime: try Scheduling.runtime(in: context))
            return ToolPreflight(
                tool: Self.definition.identifier,
                risk: Self.definition.risk,
                summary: "Create '\(plan.draft.title)' on \(plan.start) – \(plan.end) in calendar \(plan.draft.calendar.title) (\(plan.source.identifier)).",
                estimates: .init(write: .init(count: 1)),
                sideEffects: ["Adds one event to \(plan.draft.calendar.title)"],
                warnings: plan.overlaps.map { "Overlaps \($0)" }
            )
        }

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let plan = try await Plan(input, runtime: try Scheduling.runtime(in: context))
            let event = try await plan.source.create(plan.draft)
            return .init(
                source: event.source,
                identifier: event.identifier,
                title: event.title,
                calendar: event.calendar.title,
                start: ScheduleTimestamp.render(event.interval.start, in: plan.zone),
                end: ScheduleTimestamp.render(event.interval.end, in: plan.zone),
                location: event.location,
                overlaps: plan.overlaps
            )
        }
    }
}

private extension Scheduling.Tools.Book {
    /// The resolved write: where it goes and what it runs into.
    struct Plan {
        let source: any CalendarSource
        let draft: EventDraft
        let zone: ScheduleTimeZone
        let overlaps: [String]

        var start: String { ScheduleTimestamp.render(draft.interval.start, in: zone) }
        var end: String { ScheduleTimestamp.render(draft.interval.end, in: zone) }

        init(_ input: Input, runtime: Scheduling.Runtime) async throws {
            let title = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else {
                throw Failure.emptyTitle
            }
            let participants = try runtime.participants(input.participants)
            let start = try ScheduleTimestamp.parse(input.start, field: "start")
            let duration = try ScheduleMinutes.parse(input.duration_minutes, default: runtime.defaults.duration)
            let interval = try ScheduleInterval(start: start, end: start.addingTimeInterval(duration.seconds))

            let (source, calendar) = try await Self.target(input.calendar, for: participants, runtime: runtime)
            let policy = runtime.policy(for: calendar)
            guard [.commitments, .reserved].contains(policy.role) else {
                throw Failure.unbookableRole(calendar: calendar.title, role: policy.role)
            }

            self.source = source
            self.zone = participants.first?.timeZone ?? runtime.defaults.timeZone
            self.draft = EventDraft(
                title: title,
                interval: interval,
                calendar: calendar,
                location: input.location?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                notes: input.notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
            self.overlaps = try await Self.overlaps(interval, for: participants, runtime: runtime, zone: zone)
        }

        /// The named calendar, or the one commitments calendar every
        /// participant owns.
        static func target(
            _ name: String?,
            for participants: [SchedulingParticipant],
            runtime: Scheduling.Runtime
        ) async throws -> (any CalendarSource, CalendarReference) {
            var visible: [(source: any CalendarSource, calendar: CalendarReference)] = []
            for source in runtime.sources {
                for calendar in try await source.calendars() {
                    visible.append((source, calendar))
                }
            }

            let wanted: (CalendarReference) -> Bool
            let label: String
            if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                label = name
                wanted = { $0.identifier == name || $0.title.caseInsensitiveCompare(name) == .orderedSame }
            } else {
                let shared = runtime.calendars.filter { policy in
                    policy.role == .commitments
                        && participants.allSatisfy { participant in
                            participant.calendars.contains { $0.describesSameCalendar(as: policy) }
                        }
                }
                guard shared.count == 1, let policy = shared.first else {
                    throw Failure.noDefaultCalendar(
                        participants: participants.map(\.identifier),
                        candidates: shared.map(\.label)
                    )
                }
                label = policy.label
                wanted = policy.matches
            }

            let matches = visible.filter { wanted($0.calendar) }
            guard let match = matches.first else {
                throw Failure.unknownCalendar(label, known: visible.map(\.calendar.title))
            }
            guard matches.count == 1 else {
                throw Failure.ambiguousCalendar(label, sources: matches.map(\.source.identifier))
            }
            return match
        }

        /// What the participants already have at that time, as lines for
        /// the approval and the result.
        static func overlaps(
            _ interval: ScheduleInterval,
            for participants: [SchedulingParticipant],
            runtime: Scheduling.Runtime,
            zone: ScheduleTimeZone
        ) async throws -> [String] {
            let timelines = try await runtime.timelines(for: participants, in: interval)
            var lines: [String] = []
            for timeline in timelines {
                let who = timeline.participant.name
                for event in timeline.blocking(overlapping: interval) + timeline.reserved(overlapping: interval) {
                    let from = ScheduleTimestamp.render(event.interval.start, in: zone)
                    let to = ScheduleTimestamp.render(event.interval.end, in: zone)
                    lines.append("\(who): \(event.title) (\(event.calendar.title), \(from) – \(to))")
                }
                if !timeline.participant.reservedHours(overlapping: interval).isEmpty {
                    lines.append("\(who): reserved hours")
                }
            }
            return lines
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
