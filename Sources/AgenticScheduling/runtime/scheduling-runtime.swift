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
            /// Appointment length when a request does not say.
            public let duration: ScheduleMinutes
            /// How far a new appointment may run over when a request does
            /// not say; kept free as a soft margin.
            public let overrun: ScheduleMinutes
            /// Hours appointments preferably fall in, scored for every
            /// request that sets no time-of-day preference of its own.
            public let preferredHours: ClockRange?
            /// What splitting a shared trip means.
            public let splitTravel: SplitTravelPolicy

            public init(
                timeZone: ScheduleTimeZone = .current(),
                buffer: ScheduleMinutes = .zero,
                travelMode: TravelMode = .driving,
                step: ScheduleMinutes? = nil,
                placement: SlotPlacement = .prefer_offered,
                duration: ScheduleMinutes? = nil,
                overrun: ScheduleMinutes = .zero,
                preferredHours: ClockRange? = nil,
                splitTravel: SplitTravelPolicy = .avoid
            ) {
                self.timeZone = timeZone
                self.buffer = buffer
                self.travelMode = travelMode
                self.step = step ?? (try? ScheduleMinutes(15)) ?? .zero
                self.placement = placement
                self.duration = duration ?? (try? ScheduleMinutes(60)) ?? .zero
                self.overrun = overrun
                self.preferredHours = preferredHours
                self.splitTravel = splitTravel
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
        /// Every configured calendar: the participants' and any listed on
        /// their own. Unconfigured calendars are commitments.
        public let calendars: [CalendarPolicy]
        public let places: any PlaceResolver
        public let travel: any TravelEstimator
        public let defaults: Defaults
        /// The team's own brief: who they are, their conventions and the
        /// questions they typically ask.
        public let context: String?

        public init(
            sources: [any CalendarSource],
            participants: [SchedulingParticipant],
            calendars: [CalendarPolicy] = [],
            places: any PlaceResolver = StaticPlaceResolver(),
            travel: any TravelEstimator = StraightLineTravelEstimator(),
            defaults: Defaults = .init(),
            context: String? = nil
        ) {
            self.sources = sources
            self.participants = participants
            var merged: [CalendarPolicy] = []
            for policy in calendars + participants.flatMap(\.calendars)
            where !merged.contains(where: { $0.describesSameCalendar(as: policy) }) {
                merged.append(policy)
            }
            self.calendars = merged
            self.places = places
            self.travel = travel
            self.defaults = defaults
            self.context = context
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
            calendars.first { $0.matches(calendar) }
                ?? CalendarPolicy(calendar.title, identifier: calendar.identifier)
        }

        /// Whether any calendar the participant owns offers slots.
        public func offersSlots(_ participant: SchedulingParticipant) -> Bool {
            (participant.calendars.isEmpty ? calendars : participant.calendars)
                .contains { $0.role == .offers || $0.allDayRole == .offers }
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
    /// Events whose participants travel together.
    public let sharedTravel: Set<ScheduledEvent>

    public init(
        participant: SchedulingParticipant,
        events: [(event: ScheduledEvent, policy: CalendarPolicy)],
        offersSlots: Bool
    ) {
        let sorted = events.sorted { $0.event.interval.start < $1.event.interval.start }
        self.participant = participant
        func reading(_ entry: (event: ScheduledEvent, policy: CalendarPolicy)) -> AgendaReading {
            entry.policy.reading(of: entry.event)
        }
        self.blocking = sorted.filter { [.blocking, .provisional].contains(reading($0)) }.map(\.event)
        self.reserved = sorted.filter { reading($0) == .reserved }.map(\.event)
        self.offers = sorted.filter { reading($0) == .offer }.map(\.event)
        self.sharedTravel = Set(sorted.filter { $0.policy.sharedTravel }.map(\.event))
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
