import Agentic
import Foundation
import Macros
import Schema

public extension Scheduling.Tools {
    @Tool("busy")
    struct Busy {
        @JSONSchema
        public struct Input: HashableSource {
            /// Inclusive window start, ISO 8601 with offset.
            public let window_start: String
            /// Exclusive window end, ISO 8601 with offset.
            public let window_end: String
            /// Participants (identifier or name). Defaults to the primary participant.
            public let participants: [String]?

            public init(window_start: String, window_end: String, participants: [String]? = nil) {
                self.window_start = window_start
                self.window_end = window_end
                self.participants = participants
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let window_start: String
            public let window_end: String
            public let participants: [ParticipantBusy]
        }

        public static let purpose =
            "Per participant within a window: merged busy time from commitments (each block listing its events), reserved time, and offered slots still open. Clipped to the window and rendered in each participant's zone."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: CapabilityContext) async throws -> Output {
            let runtime = try Scheduling.runtime(in: context)
            let window = try ScheduleTimestamp.window(start: input.window_start, end: input.window_end)
            let participants = try runtime.participants(input.participants)
            let timelines = try await runtime.timelines(for: participants, in: window)
            return .init(
                window_start: input.window_start,
                window_end: input.window_end,
                participants: timelines.map { Self.busy($0, in: window) }
            )
        }

        static func busy(_ timeline: ParticipantTimeline, in window: ScheduleInterval) -> ParticipantBusy {
            let zone = timeline.participant.timeZone
            let blocks = timeline.busy.compactMap { interval in
                block(interval, events: timeline.blocking(overlapping: interval), window: window, zone: zone)
            }
            return .init(
                participant: timeline.participant.identifier,
                time_zone: zone.raw,
                blocks: blocks,
                busy_minutes: blocks.reduce(0) { $0 + $1.minutes },
                reserved: timeline.reserved.compactMap { event in
                    block(event.interval, events: [event], window: window, zone: zone)
                },
                open_offers: timeline.offers
                    .filter { !timeline.isBusy(during: $0.interval) }
                    .compactMap { event in block(event.interval, events: [event], window: window, zone: zone) }
            )
        }

        private static func block(
            _ interval: ScheduleInterval,
            events: [ScheduledEvent],
            window: ScheduleInterval,
            zone: ScheduleTimeZone
        ) -> BusyBlock? {
            guard let clipped = try? ScheduleInterval(
                start: max(interval.start, window.start),
                end: min(interval.end, window.end)
            ) else {
                return nil
            }
            return BusyBlock(
                start: ScheduleTimestamp.render(clipped.start, in: zone),
                end: ScheduleTimestamp.render(clipped.end, in: zone),
                minutes: clipped.minutes,
                events: events.map(\.title)
            )
        }
    }
}
