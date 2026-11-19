import Foundation
import Macros
import Schema

/// How an event repeats. Set when the event is created; changes apply to
/// one occurrence and leave the series as it is.
@JSONSchema
public struct EventRecurrence: Sendable, Codable, Hashable {
    @JSONSchema
    public enum Frequency: String, Sendable, Codable, Hashable, CaseIterable {
        case daily
        case weekly
        case monthly
        case yearly
    }

    public let frequency: Frequency
    /// Every n-th period, such as 2 for every other week. Default 1.
    public let interval: Int?
    /// Ends after this many occurrences, the first included.
    public let count: Int?
    /// Ends on this date, ISO 8601: no occurrence starts after it.
    public let until: String?

    public init(
        frequency: Frequency,
        interval: Int? = nil,
        count: Int? = nil,
        until: String? = nil
    ) {
        self.frequency = frequency
        self.interval = interval
        self.count = count
        self.until = until
    }

    /// Rejects what no calendar can store: a zero step, a zero count, or
    /// both a count and an end date.
    public func validated() throws -> EventRecurrence {
        if let interval, interval < 1 { throw Scheduling.EventWriteFailure.invalidRecurrence("interval must be 1 or more") }
        if let count, count < 1 { throw Scheduling.EventWriteFailure.invalidRecurrence("count must be 1 or more") }
        if count != nil, until != nil { throw Scheduling.EventWriteFailure.invalidRecurrence("give a count or an end date, not both") }
        if let until { _ = try ScheduleTimestamp.parse(until, field: "repeats.until") }
        return self
    }

    /// `every week`, `every 2 weeks, 5 times`, `every month until 2027-03-01`.
    public var text: String {
        let step = interval ?? 1
        let unit: String
        switch frequency {
        case .daily: unit = "day"
        case .weekly: unit = "week"
        case .monthly: unit = "month"
        case .yearly: unit = "year"
        }
        var text = step == 1 ? "every \(unit)" : "every \(step) \(unit)s"
        if let count { text += ", \(count) times" }
        if let until { text += " until \(until.prefix(10))" }
        return text
    }
}

/// Something an event can carry besides its time, place and calendar.
public enum EventDetail: String, Sendable, Hashable, CaseIterable {
    case notes
    case url
    case alerts
    case travel
    case attachments
    case recurrence

    /// For a warning: `travel time`, `attachments`.
    public var name: String {
        switch self {
        case .notes: "notes"
        case .url: "a link"
        case .alerts: "alerts"
        case .travel: "travel time"
        case .attachments: "attachments"
        case .recurrence: "repetition"
        }
    }
}

/// What an event carries besides its time, place and calendar.
public struct EventDetails: Sendable, Hashable {
    public var notes: String?
    public var url: URL?
    /// Notifications, before the start.
    public var alerts: [ScheduleMinutes]
    /// Time set aside to get there, before the start.
    public var travel: ScheduleMinutes?
    /// Files or links, by path or URL.
    public var attachments: [String]
    public var recurrence: EventRecurrence?

    public init(
        notes: String? = nil,
        url: URL? = nil,
        alerts: [ScheduleMinutes] = [],
        travel: ScheduleMinutes? = nil,
        attachments: [String] = [],
        recurrence: EventRecurrence? = nil
    ) {
        self.notes = notes
        self.url = url
        self.alerts = alerts
        self.travel = travel
        self.attachments = attachments
        self.recurrence = recurrence
    }

    public static let none = EventDetails()

    /// The details this value sets.
    public var present: Set<EventDetail> {
        var set: Set<EventDetail> = []
        if notes != nil { set.insert(.notes) }
        if url != nil { set.insert(.url) }
        if !alerts.isEmpty { set.insert(.alerts) }
        if travel != nil { set.insert(.travel) }
        if !attachments.isEmpty { set.insert(.attachments) }
        if recurrence != nil { set.insert(.recurrence) }
        return set
    }

    /// Only what `stored` allows; a source drops nothing silently because
    /// the approval already warned about the rest.
    public func keeping(_ stored: Set<EventDetail>) -> EventDetails {
        EventDetails(
            notes: stored.contains(.notes) ? notes : nil,
            url: stored.contains(.url) ? url : nil,
            alerts: stored.contains(.alerts) ? alerts : [],
            travel: stored.contains(.travel) ? travel : nil,
            attachments: stored.contains(.attachments) ? attachments : [],
            recurrence: stored.contains(.recurrence) ? recurrence : nil
        )
    }
}

/// What to change in an event's details; `nil` keeps the current value and
/// an empty list clears one.
public struct EventDetailsChange: Sendable, Hashable {
    public var notes: String?
    public var url: URL?
    public var alerts: [ScheduleMinutes]?
    public var travel: ScheduleMinutes?
    public var attachments: [String]?

    public init(
        notes: String? = nil,
        url: URL? = nil,
        alerts: [ScheduleMinutes]? = nil,
        travel: ScheduleMinutes? = nil,
        attachments: [String]? = nil
    ) {
        self.notes = notes
        self.url = url
        self.alerts = alerts
        self.travel = travel
        self.attachments = attachments
    }

    public var isEmpty: Bool {
        notes == nil && url == nil && alerts == nil && travel == nil && attachments == nil
    }

    public var present: Set<EventDetail> {
        var set: Set<EventDetail> = []
        if notes != nil { set.insert(.notes) }
        if url != nil { set.insert(.url) }
        if alerts != nil { set.insert(.alerts) }
        if travel != nil { set.insert(.travel) }
        if attachments != nil { set.insert(.attachments) }
        return set
    }

    /// `details` with this change applied.
    public func applied(to details: EventDetails) -> EventDetails {
        EventDetails(
            notes: notes ?? details.notes,
            url: url ?? details.url,
            alerts: alerts ?? details.alerts,
            travel: travel ?? details.travel,
            attachments: attachments ?? details.attachments,
            recurrence: details.recurrence
        )
    }
}
