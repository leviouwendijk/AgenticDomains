import Foundation
import Macros
import Schema

/// Someone whose time the scheduler reasons about.
public struct SchedulingParticipant: Sendable, Hashable {
    public let identifier: String
    public let name: String
    public let timeZone: ScheduleTimeZone
    public let workingHours: WorkingHours
    /// Calendars that represent this person's time. Empty means every
    /// calendar of every source, which only makes sense for a single person.
    public let calendars: [CalendarPolicy]
    /// Where the participant's day usually starts and ends, as location
    /// text (an address or a known place). Travel from and to it counts
    /// towards a placement's added travel, never as a hard limit.
    public let home: String?
    /// Time held back by default each week, such as an office day or
    /// development days. Opened by escalation, or by an offered slot.
    public let reservedHours: WorkingHours
    /// What this person does, in the team's own words.
    public let about: String?

    public init(
        identifier: String,
        name: String,
        timeZone: ScheduleTimeZone,
        workingHours: WorkingHours = .weekdays,
        calendars: [CalendarPolicy] = [],
        home: String? = nil,
        reservedHours: WorkingHours = .init([:]),
        about: String? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.timeZone = timeZone
        self.workingHours = workingHours
        self.calendars = calendars
        self.home = home
        self.reservedHours = reservedHours
        self.about = about
    }

    /// The reserved-hours ranges the interval overlaps, on its start day.
    public func reservedHours(overlapping slot: ScheduleInterval) -> [(day: ScheduleWeekday, range: ClockRange)] {
        let day = ScheduleWeekday.of(slot.start, in: timeZone)
        let from = timeZone.minutes(of: slot.start, since: slot.start)
        let to = timeZone.minutes(of: slot.end, since: slot.start)
        return reservedHours.ranges(on: day)
            .filter { from < $0.to.minuteOfDay && to > $0.from.minuteOfDay }
            .map { (day, $0) }
    }

    /// The weekly reserved hours as concrete stretches of time within the
    /// window, clipped to it, in the participant's zone.
    public func reservedIntervals(in window: ScheduleInterval) -> [ScheduleInterval] {
        let calendar = timeZone.calendar
        var result: [ScheduleInterval] = []
        var day = calendar.startOfDay(for: window.start)
        while day < window.end {
            for range in reservedHours.ranges(on: ScheduleWeekday.of(day, in: timeZone)) {
                guard let from = calendar.date(byAdding: .minute, value: range.from.minuteOfDay, to: day),
                      let to = calendar.date(byAdding: .minute, value: range.to.minuteOfDay, to: day),
                      let clipped = try? ScheduleInterval(start: max(from, window.start), end: min(to, window.end))
                else { continue }
                result.append(clipped)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    public func owns(_ event: ScheduledEvent) -> Bool {
        calendars.isEmpty || calendars.contains { $0.matches(event.calendar) }
    }
}

/// Cases follow `Calendar`'s Sunday-first `weekday` component (1...7).
@JSONSchema
public enum ScheduleWeekday: String, Sendable, Hashable, Codable, CaseIterable {
    case sunday
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    public init?(component: Int) {
        guard (1...7).contains(component) else {
            return nil
        }
        self = Self.allCases[component - 1]
    }

    public static func of(_ date: Date, in zone: ScheduleTimeZone) -> ScheduleWeekday {
        ScheduleWeekday(component: zone.calendar.component(.weekday, from: date)) ?? .monday
    }
}

/// Working time per weekday, in the participant's own zone.
public struct WorkingHours: Sendable, Hashable {
    public let ranges: [ScheduleWeekday: [ClockRange]]

    public init(_ ranges: [ScheduleWeekday: [ClockRange]]) {
        self.ranges = ranges
    }

    public func ranges(on day: ScheduleWeekday) -> [ClockRange] {
        ranges[day] ?? []
    }

    /// Monday to Friday, 09:00 to 17:00.
    public static var weekdays: WorkingHours {
        let day: [ClockRange] = (try? ClockRange(from: "09:00", to: "17:00")).map { [$0] } ?? []
        return .init([
            .monday: day, .tuesday: day, .wednesday: day, .thursday: day, .friday: day,
        ])
    }

    /// No restriction.
    public static var always: WorkingHours {
        let day: [ClockRange] = (try? ClockRange(from: "00:00", to: "24:00")).map { [$0] } ?? []
        return .init(Dictionary(uniqueKeysWithValues: ScheduleWeekday.allCases.map { ($0, day) }))
    }
}
