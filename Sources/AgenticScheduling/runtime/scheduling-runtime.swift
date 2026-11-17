import Foundation

public extension Scheduling {
    /// What the scheduling tools work against, supplied by the application
    /// through `ToolServices`.
    struct Runtime: Sendable {
        public struct Defaults: Sendable, Hashable {
            /// Zone for requests that name none.
            public let timeZone: ScheduleTimeZone
            /// Minimum gap kept around new appointments, and expected
            /// between existing ones.
            public let buffer: ScheduleMinutes
            public let travelMode: TravelMode
            /// Granularity of candidate start times.
            public let step: ScheduleMinutes
            /// How offered slots constrain placement when a request does not say.
            public let placement: SlotPlacement

            public init(
                timeZone: ScheduleTimeZone = .current(),
                buffer: ScheduleMinutes = .zero,
                travelMode: TravelMode = .driving,
                step: ScheduleMinutes? = nil,
                placement: SlotPlacement = .prefer_offered
            ) {
                self.timeZone = timeZone
                self.buffer = buffer
                self.travelMode = travelMode
                self.step = step ?? (try? ScheduleMinutes(15)) ?? .zero
                self.placement = placement
            }
        }

        public enum Failure: Error, Sendable, LocalizedError {
            case noParticipants
            case unknownParticipant(String, known: [String])

            public var errorDescription: String? {
                switch self {
                case .noParticipants:
                    return "No scheduling participants are configured."
                case .unknownParticipant(let name, let known):
                    return "Unknown participant '\(name)'. Known: \(known.joined(separator: ", "))."
                }
            }
        }

        public let sources: [any CalendarSource]
        /// The first participant is the primary one: the default when a
        /// request names nobody.
        public let participants: [SchedulingParticipant]
        /// How to read each calendar; unlisted calendars are commitments.
        public let calendars: [CalendarPolicy]
        public let places: any PlaceResolver
        public let travel: any TravelEstimator
        public let defaults: Defaults

        public init(
            sources: [any CalendarSource],
            participants: [SchedulingParticipant],
            calendars: [CalendarPolicy] = [],
            places: any PlaceResolver = StaticPlaceResolver(),
            travel: any TravelEstimator = StraightLineTravelEstimator(),
            defaults: Defaults = .init()
        ) {
            self.sources = sources
            self.participants = participants
            self.calendars = calendars
            self.places = places
            self.travel = travel
            self.defaults = defaults
        }

        /// Resolves names by identifier or name, ignoring case. `nil` or an
        /// empty list means the primary participant.
        public func participants(_ names: [String]?) throws -> [SchedulingParticipant] {
            guard let primary = participants.first else {
                throw Failure.noParticipants
            }
            guard let names, !names.isEmpty else {
                return [primary]
            }
            var resolved: [SchedulingParticipant] = []
            for name in names {
                let participant = try participant(name)
                if !resolved.contains(participant) {
                    resolved.append(participant)
                }
            }
            return resolved
        }

        public func participant(_ name: String) throws -> SchedulingParticipant {
            let match = participants.first {
                $0.identifier.caseInsensitiveCompare(name) == .orderedSame
                    || $0.name.caseInsensitiveCompare(name) == .orderedSame
            }
            guard let match else {
                throw Failure.unknownParticipant(name, known: participants.map(\.identifier))
            }
            return match
        }

        /// Events from every source overlapping `interval`, sorted by start.
        public func events(in interval: ScheduleInterval) async throws -> [ScheduledEvent] {
            let batches = try await withThrowingTaskGroup(of: [ScheduledEvent].self) { group in
                for source in sources {
                    group.addTask {
                        try await source.events(in: interval)
                    }
                }
                var all: [[ScheduledEvent]] = []
                for try await batch in group {
                    all.append(batch)
                }
                return all
            }
            var seen: Set<String> = []
            return batches.joined()
                .filter { event in
                    seen.insert("\(event.source)|\(event.identifier)|\(event.interval.start.timeIntervalSince1970)").inserted
                }
                .sorted { $0.interval.start < $1.interval.start }
        }

        public func policy(for calendar: CalendarReference) -> CalendarPolicy {
            calendars.first { calendar.matches($0.calendar) }
                ?? CalendarPolicy(calendar.title)
        }

        /// Whether any calendar the participant owns offers slots.
        public func offersSlots(_ participant: SchedulingParticipant) -> Bool {
            calendars.contains { policy in
                policy.role == .offers
                    && (participant.calendars.isEmpty || participant.calendars.contains(where: policy.names))
            }
        }

        /// Each participant's events overlapping `interval`.
        public func timelines(
            for participants: [SchedulingParticipant],
            in interval: ScheduleInterval
        ) async throws -> [ParticipantTimeline] {
            let events = try await events(in: interval)
            return participants.map { participant in
                ParticipantTimeline(
                    participant: participant,
                    events: events
                        .filter { participant.owns($0) }
                        .map { ($0, policy(for: $0.calendar)) },
                    offersSlots: offersSlots(participant)
                )
            }
        }
    }
}

/// One participant's events, read through their calendars' roles.
public struct ParticipantTimeline: Sendable {
    public let participant: SchedulingParticipant
    /// Commitments that block time, sorted by start.
    public let blocking: [ScheduledEvent]
    /// Reserved time, sorted by start, whatever each event's availability.
    public let reserved: [ScheduledEvent]
    /// Offered slots, sorted by start.
    public let offers: [ScheduledEvent]
    /// Merged busy intervals of the blocking commitments.
    public let busy: [ScheduleInterval]
    /// Whether this participant has calendars that offer slots at all, so
    /// an absence of offers means "nothing offered" rather than "not used".
    public let offersSlots: Bool
    private let overruns: [ScheduledEvent: ScheduleMinutes]

    public init(
        participant: SchedulingParticipant,
        events: [(event: ScheduledEvent, policy: CalendarPolicy)],
        offersSlots: Bool
    ) {
        let sorted = events.sorted { $0.event.interval.start < $1.event.interval.start }
        self.participant = participant
        self.blocking = sorted.filter { $0.policy.role == .commitments && $0.event.blocks }.map(\.event)
        self.reserved = sorted.filter { $0.policy.role == .reserved }.map(\.event)
        self.offers = sorted.filter { $0.policy.role == .offers }.map(\.event)
        self.busy = ScheduleInterval.merged(blocking.map(\.interval))
        self.offersSlots = offersSlots
        self.overruns = Dictionary(
            sorted.filter { $0.policy.overrun > .zero }.map { ($0.event, $0.policy.overrun) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    public func blocking(overlapping interval: ScheduleInterval) -> [ScheduledEvent] {
        blocking.filter { $0.interval.overlaps(interval) }
    }

    public func reserved(overlapping interval: ScheduleInterval) -> [ScheduledEvent] {
        reserved.filter { $0.interval.overlaps(interval) }
    }

    public func isBusy(during interval: ScheduleInterval) -> Bool {
        busy.contains { $0.overlaps(interval) }
    }

    /// Whether an offered slot covers the whole interval.
    public func isOffered(_ interval: ScheduleInterval) -> Bool {
        offers.contains { $0.interval.contains(interval) }
    }

    public func overrun(of event: ScheduledEvent) -> ScheduleMinutes {
        overruns[event] ?? .zero
    }

    /// Whether any of the participant's commitments usually overrun.
    public var hasOverruns: Bool {
        !overruns.isEmpty
    }
}
