import Agentic
import Foundation
import Macros
import Schema

public extension Scheduling.Tools {
    @Tool("conflicts")
    struct Conflicts {
        @JSONSchema
        public struct Input: HashableSource {
            /// Inclusive window start, ISO 8601 with offset.
            public let window_start: String
            /// Exclusive window end, ISO 8601 with offset.
            public let window_end: String
            /// Participants (identifier or name). Defaults to the primary participant.
            public let participants: [String]?
            /// Minimum expected gap between consecutive appointments. Defaults
            /// to the configured buffer.
            public let buffer_minutes: Int?
            /// Travel mode for feasibility between located events. Defaults to
            /// the configured mode.
            public let travel_mode: TravelMode?

            public init(
                window_start: String,
                window_end: String,
                participants: [String]? = nil,
                buffer_minutes: Int? = nil,
                travel_mode: TravelMode? = nil
            ) {
                self.window_start = window_start
                self.window_end = window_end
                self.participants = participants
                self.buffer_minutes = buffer_minutes
                self.travel_mode = travel_mode
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let conflicts: [ScheduleConflict]
            public let events_considered: Int
            public let information_gaps: [String]
        }

        public static let purpose =
            "Per participant within a window, find overlapping commitments, gaps shorter than the buffer or than an appointment's usual overrun, consecutive same-day appointments too far apart to travel between, commitments placed in reserved time, and shared trips that split (participants travelling together who arrive from or leave for different places)."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let runtime = try Scheduling.runtime(in: context)
            let window = try ScheduleTimestamp.window(start: input.window_start, end: input.window_end)
            let participants = try runtime.participants(input.participants)
            let buffer = try parsed("buffer_minutes") {
                try ScheduleMinutes.parse(input.buffer_minutes, default: runtime.defaults.buffer)
            }
            let timelines = try await runtime.timelines(for: participants, in: window)
            let oracle = TravelOracle(
                resolver: runtime.places,
                estimator: runtime.travel,
                mode: input.travel_mode ?? runtime.defaults.travelMode
            )
            let detection = ConflictDetection(buffer: buffer, oracle: oracle)

            var conflicts: [ScheduleConflict] = []
            for timeline in timelines {
                conflicts += await detection.conflicts(in: timeline)
            }
            conflicts += try await Self.splitTravel(among: participants, in: window, runtime: runtime)
            return .init(
                conflicts: conflicts,
                events_considered: timelines.reduce(0) { $0 + $1.blocking.count },
                information_gaps: await oracle.gaps
            )
        }

        /// Shared trips that already split, involving any of the participants.
        /// Every participant's timeline is read, since a travel partner may
        /// not be among them.
        static func splitTravel(
            among participants: [SchedulingParticipant],
            in window: ScheduleInterval,
            runtime: Scheduling.Runtime
        ) async throws -> [ScheduleConflict] {
            let team = try await runtime.timelines(for: runtime.participants, in: window)
            let asked = Set(participants.map(\.identifier))
            var items: [String: [SharedTravel.Item]] = [:]
            var zones: [String: ScheduleTimeZone] = [:]
            for timeline in team {
                items[timeline.participant.identifier] = SharedTravel.items(timeline)
                zones[timeline.participant.identifier] = timeline.participant.timeZone
            }
            return SharedTravel.splits(items, zones: zones).compactMap { split in
                guard
                    split.stops.contains(where: { asked.contains($0.participant) }),
                    let trip = split.trip.event,
                    let diverging = split.diverging,
                    let other = diverging.stop.event,
                    let zone = zones[diverging.participant]
                else {
                    return nil
                }
                let first = split.arriving ? other : trip
                let second = split.arriving ? trip : other
                return ScheduleConflict(
                    kind: .split_travel,
                    participant: diverging.participant,
                    first: .init(trip, in: zone),
                    second: .init(other, in: zone),
                    gap_minutes: wholeMinutes(second.interval.start.timeIntervalSince(first.interval.end)),
                    required_minutes: nil,
                    travel: nil,
                    detail: "Shared trip splits \(split.description)."
                )
            }
        }
    }
}
