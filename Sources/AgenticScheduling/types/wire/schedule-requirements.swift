import Agentic
import Macros
import Schema

/// What a new appointment needs. Shared by slot search and evaluation.
@JSONSchema
public struct SlotRequirements: HashableSource {
    /// Length of the appointment in minutes. Defaults to the configured
    /// length.
    public let duration_minutes: Int?
    /// Participants who must attend (identifier or name). Defaults to the
    /// primary participant.
    public let participants: [String]?
    /// Participants whose attendance is preferred but not required.
    public let optional_participants: [String]?
    /// IANA zone for time-of-day, weekday and rendered times. Defaults to
    /// the configured zone.
    public let time_zone: String?
    /// Keep within each required participant's working hours. Default true.
    public let working_hours_only: Bool?
    /// Earliest start time of day, `HH:mm`, in `time_zone`.
    public let earliest_time: String?
    /// Latest end time of day, `HH:mm`, in `time_zone`.
    public let latest_time: String?
    /// Allowed weekdays in `time_zone`; empty or absent allows all.
    public let weekdays: [ScheduleWeekday]?
    /// Free minutes required before the appointment. Defaults to the
    /// configured buffer.
    public let buffer_before_minutes: Int?
    /// Free minutes required after the appointment. Defaults to the
    /// configured buffer.
    public let buffer_after_minutes: Int?
    /// Where the appointment takes place, such as the client's address.
    /// When it resolves, travel from and to adjacent located events on the
    /// same day must fit, and added travel is scored.
    public let location: String?
    /// Travel mode for feasibility checks. Defaults to the configured mode.
    public let travel_mode: TravelMode?
    /// How offered slots constrain placement. Defaults to the configured
    /// placement.
    public let placement: SlotPlacement?
    /// Escalation: allow placement in reserved time. Default false.
    public let allow_reserved: Bool?
    /// How far the new appointment may run past its nominal end; a soft
    /// margin kept before the next commitment. Defaults to the configured
    /// margin.
    public let overrun_minutes: Int?
    /// Whether the required participants travel together to this
    /// appointment. Defaults to true when more than one is required and a
    /// location is given.
    public let shared_travel: Bool?
    /// Escalation: allow a placement that splits a shared trip, so a second
    /// vehicle is needed. Default false.
    public let allow_split_travel: Bool?
    /// Weighted soft preferences. Absent means "earlier is better".
    public let preferences: [SlotPreference]?

    public init(
        duration_minutes: Int? = nil,
        participants: [String]? = nil,
        optional_participants: [String]? = nil,
        time_zone: String? = nil,
        working_hours_only: Bool? = nil,
        earliest_time: String? = nil,
        latest_time: String? = nil,
        weekdays: [ScheduleWeekday]? = nil,
        buffer_before_minutes: Int? = nil,
        buffer_after_minutes: Int? = nil,
        location: String? = nil,
        travel_mode: TravelMode? = nil,
        placement: SlotPlacement? = nil,
        allow_reserved: Bool? = nil,
        overrun_minutes: Int? = nil,
        shared_travel: Bool? = nil,
        allow_split_travel: Bool? = nil,
        preferences: [SlotPreference]? = nil
    ) {
        self.duration_minutes = duration_minutes
        self.participants = participants
        self.optional_participants = optional_participants
        self.time_zone = time_zone
        self.working_hours_only = working_hours_only
        self.earliest_time = earliest_time
        self.latest_time = latest_time
        self.weekdays = weekdays
        self.buffer_before_minutes = buffer_before_minutes
        self.buffer_after_minutes = buffer_after_minutes
        self.location = location
        self.travel_mode = travel_mode
        self.placement = placement
        self.allow_reserved = allow_reserved
        self.overrun_minutes = overrun_minutes
        self.shared_travel = shared_travel
        self.allow_split_travel = allow_split_travel
        self.preferences = preferences
    }
}

@JSONSchema
public enum SlotPlacement:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    /// Each required participant who offers slots must have one covering
    /// the appointment.
    case offered_only
    /// Offered slots score higher; open time is still feasible.
    case prefer_offered
    /// Offered slots play no part.
    case any
}

@JSONSchema
public enum SlotPreferenceKind:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    /// Earlier in the window scores higher.
    case earlier
    /// Later in the window scores higher.
    case later
    /// Inside `from`...`to` scores fully; it decays over three hours outside.
    case time_of_day
    /// At least 30 minutes from the nearest busy time scores fully.
    case avoid_back_to_back
}

@JSONSchema
public struct SlotPreference: HashableSource {
    public let kind: SlotPreferenceKind
    /// Relative weight, greater than zero. Default 1.
    public let weight: Double?
    /// Range start, `HH:mm`; `time_of_day` only.
    public let from: String?
    /// Range end, `HH:mm`; `time_of_day` only.
    public let to: String?

    public init(kind: SlotPreferenceKind, weight: Double? = nil, from: String? = nil, to: String? = nil) {
        self.kind = kind
        self.weight = weight
        self.from = from
        self.to = to
    }
}
