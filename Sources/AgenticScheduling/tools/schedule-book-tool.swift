import Agentic
import Foundation
import Macros
import Schema

public extension Scheduling.Tools {
    /// Writes one appointment into a calendar. The user approves it from its
    /// preflight, which names the calendar, what the appointment would
    /// overlap and the offered slot it fills.
    @Tool("book")
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
            /// A link to keep with the event, such as a video call.
            public let url: String?
            /// Notifications, in minutes before the start: `[1440, 15]` is a
            /// day before and a quarter of an hour before.
            public let alerts_minutes_before: [Int]?
            /// Minutes set aside to get there, blocked before the start.
            public let travel_minutes: Int?
            /// Files (workspace paths) or links to attach.
            public let attachments: [String]?
            /// Makes it a recurring event.
            public let repeats: EventRecurrence?
            /// Converts the open offered slot holding the appointment: the
            /// offer is removed once the appointment is written. Defaults
            /// to false.
            public let fill_offer: Bool?

            public init(
                title: String,
                start: String,
                duration_minutes: Int? = nil,
                participants: [String]? = nil,
                calendar: String? = nil,
                location: String? = nil,
                notes: String? = nil,
                url: String? = nil,
                alerts_minutes_before: [Int]? = nil,
                travel_minutes: Int? = nil,
                attachments: [String]? = nil,
                repeats: EventRecurrence? = nil,
                fill_offer: Bool? = nil
            ) {
                self.title = title
                self.start = start
                self.duration_minutes = duration_minutes
                self.participants = participants
                self.calendar = calendar
                self.location = location
                self.notes = notes
                self.url = url
                self.alerts_minutes_before = alerts_minutes_before
                self.travel_minutes = travel_minutes
                self.attachments = attachments
                self.repeats = repeats
                self.fill_offer = fill_offer
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
            /// The offered slot removed because the appointment fills it.
            public let removed_offer: String?
        }

        public static let purpose =
            "Create one appointment in a calendar, after the user has agreed to a time. Writes into the participants' shared commitments calendar unless a calendar is named; with fill_offer it also removes the offered slot it fills."
        public static let risk: ActionRisk = .boundedmutate

        public init() {}

        public func preflight(_ input: Input, in context: ToolContext) async throws -> ToolPreflight {
            let runtime = try Scheduling.runtime(in: context)
            let plan = try await Plan(input, runtime: runtime)
            var sideEffects = ["Adds one event to \(plan.draft.calendar.title)"]
            if let offer = plan.offer {
                sideEffects.append("Removes the offered slot \(runtime.describe(offer, in: plan.zone))")
            }
            return ToolPreflight(
                tool: Self.definition.identifier,
                risk: Self.definition.risk,
                summary: "Create '\(plan.draft.title)' on \(plan.start) – \(plan.end) in calendar \(plan.draft.calendar.title) (\(plan.source.identifier)).",
                estimates: .init(write: .init(count: sideEffects.count)),
                preview: try await runtime.eventPreview(
                    title: plan.draft.title,
                    interval: plan.draft.interval,
                    change: .create,
                    calendar: plan.draft.calendar.title,
                    location: plan.draft.location,
                    details: plan.draft.details,
                    participants: plan.participants,
                    zone: plan.zone,
                    overlaps: plan.overlaps,
                    unstored: plan.unstored,
                    facts: plan.offer.map { [.init("fills offer", runtime.describe($0, in: plan.zone))] } ?? []
                ),
                sideEffects: sideEffects,
                warnings: plan.overlaps.map { "Overlaps \($0)" }
            )
        }

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let runtime = try Scheduling.runtime(in: context)
            let plan = try await Plan(input, runtime: runtime)
            let event = try await plan.source.create(plan.draft)
            if let offer = plan.offer {
                try await runtime.source(named: offer.source).remove(offer)
            }
            return .init(
                source: event.source,
                identifier: event.identifier,
                title: event.title,
                calendar: event.calendar.title,
                start: ScheduleTimestamp.render(event.interval.start, in: plan.zone),
                end: ScheduleTimestamp.render(event.interval.end, in: plan.zone),
                location: event.location,
                overlaps: plan.overlaps,
                removed_offer: plan.offer.map { runtime.describe($0, in: plan.zone) }
            )
        }
    }
}

private extension Scheduling.Tools.Book {
    /// The resolved write: where it goes, what it runs into, which offer it fills.
    struct Plan {
        let source: any CalendarSource
        let draft: EventDraft
        let participants: [SchedulingParticipant]
        let zone: ScheduleTimeZone
        let overlaps: [String]
        /// Requested details the source cannot store.
        let unstored: [String]
        let offer: ScheduledEvent?

        var start: String { ScheduleTimestamp.render(draft.interval.start, in: zone) }
        var end: String { ScheduleTimestamp.render(draft.interval.end, in: zone) }

        init(_ input: Input, runtime: Scheduling.Runtime) async throws {
            guard let title = input.title.trimmedNonEmpty else {
                throw Scheduling.EventWriteFailure.emptyTitle
            }
            let participants = try runtime.participants(input.participants)
            let start = try ScheduleTimestamp.parse(input.start, field: "start")
            let duration = try ScheduleMinutes.parse(input.duration_minutes, default: runtime.defaults.duration)
            let interval = try ScheduleInterval(start: start, end: start.addingTimeInterval(duration.seconds))
            let target = try await runtime.writableCalendar(input.calendar, for: participants)
            let zone = participants.first?.timeZone ?? runtime.defaults.timeZone
            let asked = try Scheduling.Runtime.details(
                notes: input.notes,
                url: input.url,
                alerts: input.alerts_minutes_before,
                travel: input.travel_minutes,
                attachments: input.attachments
            ).applied(to: .init(recurrence: try input.repeats?.validated()))
            self.unstored = runtime.unstored(asked.present, in: target.source)

            self.source = target.source
            self.participants = participants
            self.zone = zone
            self.draft = EventDraft(
                title: title,
                interval: interval,
                calendar: target.calendar,
                location: input.location?.trimmedNonEmpty,
                details: asked.keeping(target.source.storedDetails)
            )
            self.overlaps = try await runtime.overlaps(interval, for: participants, zone: zone)
            self.offer = input.fill_offer == true
                ? try await runtime.openOffer(holding: interval, for: participants, zone: zone)
                : nil
        }
    }
}
