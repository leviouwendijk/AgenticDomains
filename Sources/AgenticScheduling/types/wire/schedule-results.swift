import Agentic
import Macros
import Schema

/// An existing event as reported back, times rendered in a zone.
@JSONSchema
public struct ScheduleEventReference: HashableResult {
    public let title: String
    public let start: String
    public let end: String
    public let calendar: String
    public let location: String?

    public init(_ event: ScheduledEvent, in zone: ScheduleTimeZone) {
        self.title = event.title
        self.start = ScheduleTimestamp.render(event.interval.start, in: zone)
        self.end = ScheduleTimestamp.render(event.interval.end, in: zone)
        self.calendar = event.calendar.title
        self.location = event.locationText
    }
}

// MARK: busy

@JSONSchema
public struct BusyBlock: HashableResult {
    public let start: String
    public let end: String
    public let minutes: Int
    /// Titles of the events making up this block.
    public let events: [String]

    public init(start: String, end: String, minutes: Int, events: [String]) {
        self.start = start
        self.end = end
        self.minutes = minutes
        self.events = events
    }
}

@JSONSchema
public struct ParticipantBusy: HashableResult {
    public let participant: String
    public let time_zone: String
    /// Commitments that block time, merged.
    public let blocks: [BusyBlock]
    public let busy_minutes: Int
    /// Reserved time: blocks unless escalated.
    public let reserved: [BusyBlock]
    /// Offered slots not taken by a commitment.
    public let open_offers: [BusyBlock]

    public init(
        participant: String,
        time_zone: String,
        blocks: [BusyBlock],
        busy_minutes: Int,
        reserved: [BusyBlock],
        open_offers: [BusyBlock]
    ) {
        self.participant = participant
        self.time_zone = time_zone
        self.blocks = blocks
        self.busy_minutes = busy_minutes
        self.reserved = reserved
        self.open_offers = open_offers
    }
}

// MARK: conflicts

@JSONSchema
public enum ScheduleConflictKind:
    String,
    Sendable,
    Codable,
    Hashable
{
    /// Two blocking events overlap.
    case overlap
    /// The gap between consecutive events is below the buffer.
    case insufficient_buffer
    /// The gap is shorter than travel between the two locations.
    case travel_infeasible
    /// The gap is shorter than the first appointment's usual overrun.
    case overrun_risk
    /// A commitment lies in reserved time (`first` is the reservation).
    case in_reserved_time
}

@JSONSchema
public struct ScheduleConflict: HashableResult {
    public let kind: ScheduleConflictKind
    public let participant: String
    public let first: ScheduleEventReference
    public let second: ScheduleEventReference
    /// Minutes from the end of `first` to the start of `second`; negative
    /// for an overlap.
    public let gap_minutes: Int
    /// Minutes the gap would need (buffer or travel); absent for overlaps.
    public let required_minutes: Int?
    public let travel: TravelEstimate?

    public init(
        kind: ScheduleConflictKind,
        participant: String,
        first: ScheduleEventReference,
        second: ScheduleEventReference,
        gap_minutes: Int,
        required_minutes: Int?,
        travel: TravelEstimate?
    ) {
        self.kind = kind
        self.participant = participant
        self.first = first
        self.second = second
        self.gap_minutes = gap_minutes
        self.required_minutes = required_minutes
        self.travel = travel
    }
}

// MARK: slots

@JSONSchema
public enum SlotConstraintKind:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case window
    case weekday
    case time_of_day
    case working_hours
    case busy
    case buffer
    case travel_before
    case travel_after
    /// Overlaps reserved time without escalation.
    case reserved
    /// Not inside an offered slot while placement requires one.
    case not_offered
}

/// Where a candidate sits relative to offered and reserved time.
@JSONSchema
public enum SlotPlacementKind:
    String,
    Sendable,
    Codable,
    Hashable
{
    /// Inside an offered slot of a required participant.
    case offered
    /// Free time that nobody offered or reserved.
    case open
    /// Opens reserved time: an escalation.
    case reserved
}

/// What a score term measures.
@JSONSchema
public enum SlotScoreTermKind:
    String,
    Sendable,
    Codable,
    Hashable
{
    case earlier
    case later
    case time_of_day
    case avoid_back_to_back
    /// Share of optional participants available.
    case optional_attendance
    /// Share of slot-offering required participants whose offer covers it.
    case offered_slot
    /// Room for the previous appointment's and this one's usual overrun.
    case overrun_margin
    /// Travel the placement adds to a participant's day; nearby scores
    /// higher.
    case added_travel
}

@JSONSchema
public struct SlotViolation: HashableResult {
    public let constraint: SlotConstraintKind
    public let participant: String?
    public let detail: String

    public init(constraint: SlotConstraintKind, participant: String?, detail: String) {
        self.constraint = constraint
        self.participant = participant
        self.detail = detail
    }
}

@JSONSchema
public struct SlotScoreTerm: HashableResult {
    public let kind: SlotScoreTermKind
    /// Parameters of the term, such as a time-of-day range.
    public let detail: String?
    public let weight: Double
    /// 0 (not met) ... 1 (fully met).
    public let satisfaction: Double

    public init(kind: SlotScoreTermKind, detail: String?, weight: Double, satisfaction: Double) {
        self.kind = kind
        self.detail = detail
        self.weight = weight
        self.satisfaction = satisfaction
    }
}

@JSONSchema
public struct TravelLeg: HashableResult {
    public let participant: String
    public let from: String
    public let to: String
    public let estimate: TravelEstimate
    /// Minutes actually available between the two appointments.
    public let available_minutes: Int

    public init(participant: String, from: String, to: String, estimate: TravelEstimate, available_minutes: Int) {
        self.participant = participant
        self.from = from
        self.to = to
        self.estimate = estimate
        self.available_minutes = available_minutes
    }
}

@JSONSchema
public struct SlotCandidate: HashableResult {
    public let start: String
    public let end: String
    public let placement: SlotPlacementKind
    /// Weighted mean of the terms, 0...1.
    public let score: Double
    public let terms: [SlotScoreTerm]
    public let optional_available: [String]
    public let optional_unavailable: [String]
    public let travel: [TravelLeg]

    public init(
        start: String,
        end: String,
        placement: SlotPlacementKind,
        score: Double,
        terms: [SlotScoreTerm],
        optional_available: [String],
        optional_unavailable: [String],
        travel: [TravelLeg]
    ) {
        self.start = start
        self.end = end
        self.placement = placement
        self.score = score
        self.terms = terms
        self.optional_available = optional_available
        self.optional_unavailable = optional_unavailable
        self.travel = travel
    }
}

@JSONSchema
public struct SlotRejection: HashableResult {
    public let constraint: SlotConstraintKind
    /// Candidate start times excluded at least partly by this constraint.
    public let count: Int

    public init(constraint: SlotConstraintKind, count: Int) {
        self.constraint = constraint
        self.count = count
    }
}
