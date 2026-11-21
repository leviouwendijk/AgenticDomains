import Agentic
import Foundation
import Macros
import Schema

public extension Scheduling.Tools {
    /// Changes one existing event: its time, length, title, location, notes
    /// or calendar. Only that occurrence of a recurring event changes.
    @Tool("update")
    struct Update {
        @JSONSchema
        public struct Input: HashableSource {
            /// The event's current start, ISO 8601 with offset, as
            /// `schedule_tool_agenda` lists it.
            public let event_start: String
            /// The event's current title, as `schedule_tool_agenda` lists it.
            public let event_title: String
            /// The event's current calendar, when the title and start alone
            /// match several events.
            public let event_calendar: String?
            /// New start, ISO 8601 with offset. Keeps the length unless
            /// `duration_minutes` is given.
            public let start: String?
            /// New length in minutes, from the (new) start.
            public let duration_minutes: Int?
            public let title: String?
            /// Calendar to move the event into.
            public let calendar: String?
            public let location: String?
            public let notes: String?
            public let url: String?
            /// Replaces the notifications, in minutes before the start; an
            /// empty list removes them.
            public let alerts_minutes_before: [Int]?
            public let travel_minutes: Int?
            /// Replaces the attachments (workspace paths or links); an
            /// empty list removes them.
            public let attachments: [String]?

            public init(
                event_start: String,
                event_title: String,
                event_calendar: String? = nil,
                start: String? = nil,
                duration_minutes: Int? = nil,
                title: String? = nil,
                calendar: String? = nil,
                location: String? = nil,
                notes: String? = nil,
                url: String? = nil,
                alerts_minutes_before: [Int]? = nil,
                travel_minutes: Int? = nil,
                attachments: [String]? = nil
            ) {
                self.event_start = event_start
                self.event_title = event_title
                self.event_calendar = event_calendar
                self.start = start
                self.duration_minutes = duration_minutes
                self.title = title
                self.calendar = calendar
                self.location = location
                self.notes = notes
                self.url = url
                self.alerts_minutes_before = alerts_minutes_before
                self.travel_minutes = travel_minutes
                self.attachments = attachments
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let source: String
            public let identifier: String
            /// The event before the change.
            public let before: String
            public let title: String
            public let calendar: String
            public let start: String
            public let end: String
            public let location: String?
            /// Other events and reserved hours the changed event overlaps,
            /// as approved by the user.
            public let overlaps: [String]
        }

        public static let purpose =
            "Change one existing event (by its start and title from \(Agenda.identifier.rawValue)): move it, change its length, title, location, notes, link, alerts, travel time or attachments, or move it to another calendar. Only that occurrence of a recurring event changes."
        public static let risk: ActionRisk = .boundedmutate

        public init() {}

        public func preflight(_ input: Input, in context: ToolContext) async throws -> ToolPreflight {
            let runtime = try Scheduling.runtime(in: context)
            let plan = try await Plan(input, runtime: runtime)
            return ToolPreflight(
                tool: Self.definition.identifier,
                risk: Self.definition.risk,
                summary: "Change \(runtime.describe(plan.event, in: plan.zone)) to \(plan.after).",
                estimates: .init(write: .init(count: 1)),
                preview: try await runtime.eventPreview(
                    title: plan.result.title,
                    interval: plan.result.interval,
                    allDay: plan.result.isAllDay,
                    change: .update,
                    previous: plan.result.interval == plan.event.interval ? nil : plan.event.interval,
                    calendar: plan.result.calendar.title,
                    location: plan.result.location,
                    details: plan.result.details,
                    participants: plan.owners,
                    zone: plan.zone,
                    overlaps: plan.overlaps,
                    unstored: plan.unstored,
                    facts: plan.result.title == plan.event.title ? [] : [.init("was titled", plan.event.title)]
                ),
                sideEffects: ["Changes one event in \(plan.event.calendar.title)"],
                warnings: plan.overlaps.map { "Overlaps \($0)" }
            )
        }

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let runtime = try Scheduling.runtime(in: context)
            let plan = try await Plan(input, runtime: runtime)
            let changed = try await plan.source.update(plan.event, with: plan.change)
            return .init(
                source: changed.source,
                identifier: changed.identifier,
                before: runtime.describe(plan.event, in: plan.zone),
                title: changed.title,
                calendar: changed.calendar.title,
                start: ScheduleTimestamp.render(changed.interval.start, in: plan.zone),
                end: ScheduleTimestamp.render(changed.interval.end, in: plan.zone),
                location: changed.location,
                overlaps: plan.overlaps
            )
        }
    }

    /// Removes one existing event. Only that occurrence of a recurring event
    /// goes.
    @Tool("remove")
    struct Remove {
        @JSONSchema
        public struct Input: HashableSource {
            /// The event's start, ISO 8601 with offset, as
            /// `schedule_tool_agenda` lists it.
            public let event_start: String
            /// The event's title, as `schedule_tool_agenda` lists it.
            public let event_title: String
            /// The event's calendar, when the title and start alone match
            /// several events.
            public let event_calendar: String?

            public init(event_start: String, event_title: String, event_calendar: String? = nil) {
                self.event_start = event_start
                self.event_title = event_title
                self.event_calendar = event_calendar
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let source: String
            /// The removed event, with its calendar and time.
            public let removed: String
        }

        public static let purpose =
            "Remove one existing event (by its start and title from \(Agenda.identifier.rawValue)), such as a cancelled appointment or an offered slot that is no longer open. Only that occurrence of a recurring event goes."
        public static let risk: ActionRisk = .boundedmutate

        public init() {}

        public func preflight(_ input: Input, in context: ToolContext) async throws -> ToolPreflight {
            let runtime = try Scheduling.runtime(in: context)
            let event = try await runtime.event(startingAt: input.event_start, title: input.event_title, calendar: input.event_calendar)
            let zone = runtime.owners(of: event.calendar).first?.timeZone ?? runtime.defaults.timeZone
            return ToolPreflight(
                tool: Self.definition.identifier,
                risk: Self.definition.risk,
                summary: "Remove \(runtime.describe(event, in: zone)).",
                estimates: .init(write: .init(count: 1)),
                preview: try await runtime.eventPreview(
                    title: event.title,
                    interval: event.interval,
                    allDay: event.isAllDay,
                    change: .cancel,
                    calendar: event.calendar.title,
                    location: event.location,
                    details: event.details,
                    participants: runtime.owners(of: event.calendar),
                    zone: zone
                ),
                sideEffects: ["Removes one event from \(event.calendar.title)"]
            )
        }

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let runtime = try Scheduling.runtime(in: context)
            let event = try await runtime.event(startingAt: input.event_start, title: input.event_title, calendar: input.event_calendar)
            let zone = runtime.owners(of: event.calendar).first?.timeZone ?? runtime.defaults.timeZone
            try await runtime.source(named: event.source).remove(event)
            return .init(source: event.source, removed: runtime.describe(event, in: zone))
        }
    }
}

private extension Scheduling.Tools.Update {
    /// The event as it is, the change, and what the result runs into.
    struct Plan {
        let source: any CalendarSource
        let event: ScheduledEvent
        let change: EventChange
        /// The event as it will read once changed.
        let result: ScheduledEvent
        let owners: [SchedulingParticipant]
        let zone: ScheduleTimeZone
        let after: String
        let unstored: [String]
        let overlaps: [String]

        init(_ input: Input, runtime: Scheduling.Runtime) async throws {
            let event = try await runtime.event(startingAt: input.event_start, title: input.event_title, calendar: input.event_calendar)

            var interval: ScheduleInterval?
            if input.start != nil || input.duration_minutes != nil {
                let start = try input.start.map { try ScheduleTimestamp.parse($0, field: "start") } ?? event.interval.start
                let seconds = try input.duration_minutes.map { try ScheduleMinutes($0).seconds }
                    ?? event.interval.end.timeIntervalSince(event.interval.start)
                interval = try ScheduleInterval(start: start, end: start.addingTimeInterval(seconds))
            }

            var calendar: CalendarReference?
            if let name = input.calendar?.trimmedNonEmpty {
                // Any role: moving an appointment into a records calendar
                // is how a team keeps a cancellation.
                let target = try await runtime.writableCalendar(
                    name,
                    for: runtime.owners(of: event.calendar),
                    roles: Set(CalendarRole.allCases)
                )
                guard target.source.identifier == event.source else {
                    throw CalendarSourceWriteFailure.calendarNotFound(source: event.source, calendar: name)
                }
                calendar = target.calendar
            }

            let title = input.title?.trimmedNonEmpty
            if input.title != nil, title == nil {
                throw Scheduling.EventWriteFailure.emptyTitle
            }

            let source = try runtime.source(named: event.source)
            let asked = try Scheduling.Runtime.details(
                notes: input.notes,
                url: input.url,
                alerts: input.alerts_minutes_before,
                travel: input.travel_minutes,
                attachments: input.attachments
            )
            let stored = source.storedDetails
            let change = EventChange(
                title: title,
                interval: interval,
                calendar: calendar,
                location: input.location?.trimmedNonEmpty,
                details: EventDetailsChange(
                    notes: stored.contains(.notes) ? asked.notes : nil,
                    url: stored.contains(.url) ? asked.url : nil,
                    alerts: stored.contains(.alerts) ? asked.alerts : nil,
                    travel: stored.contains(.travel) ? asked.travel : nil,
                    attachments: stored.contains(.attachments) ? asked.attachments : nil
                )
            )
            guard !change.isEmpty else {
                throw Scheduling.EventWriteFailure.nothingToChange
            }

            let finalCalendar = calendar ?? event.calendar
            let owners = runtime.owners(of: finalCalendar)
            let zone = owners.first?.timeZone ?? runtime.defaults.timeZone
            let finalInterval = interval ?? event.interval
            let preview = ScheduledEvent(
                source: event.source,
                identifier: event.identifier,
                title: title ?? event.title,
                interval: finalInterval,
                isAllDay: event.isAllDay,
                calendar: finalCalendar,
                availability: event.availability,
                location: change.location ?? event.location,
                details: change.details.applied(to: event.details)
            )

            self.source = source
            self.unstored = runtime.unstored(asked.present, in: source)
            self.event = event
            self.change = change
            self.result = preview
            self.owners = owners
            self.zone = zone
            self.after = runtime.describe(preview, in: zone)
                + (change.location.map { " at \($0)" } ?? "")
            self.overlaps = interval == nil
                ? []
                : try await runtime.overlaps(finalInterval, for: owners, zone: zone, excluding: event)
        }
    }
}
