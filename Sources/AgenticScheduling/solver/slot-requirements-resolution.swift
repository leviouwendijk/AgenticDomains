import Foundation
import Primitives

public extension Scheduling {
    /// A tool input field that does not parse.
    enum InputFailure: Error, Sendable, LocalizedError {
        case invalid(field: String, reason: String)

        public var errorDescription: String? {
            switch self {
            case .invalid(let field, let reason):
                return "Invalid \(field): \(reason)"
            }
        }
    }
}

func parsed<Value>(_ field: String, _ body: () throws -> Value) throws -> Value {
    do {
        return try body()
    } catch let failure as InvarianceFailure {
        throw Scheduling.InputFailure.invalid(
            field: field,
            reason: failure.violations.map(\.message).joined(separator: "; ")
        )
    } catch {
        throw Scheduling.InputFailure.invalid(field: field, reason: error.localizedDescription)
    }
}

/// `SlotRequirements` parsed into guaranteed values against a runtime.
struct ResolvedRequirements: Sendable {
    enum Preference: Sendable {
        case earlier(Double)
        case later(Double)
        case timeOfDay(ClockRange, Double)
        case avoidBackToBack(Double)
    }

    let duration: ScheduleMinutes
    let required: [SchedulingParticipant]
    let optional: [SchedulingParticipant]
    let zone: ScheduleTimeZone
    let workingHoursOnly: Bool
    let timeOfDay: ClockRange?
    let weekdays: Set<ScheduleWeekday>?
    let bufferBefore: ScheduleMinutes
    let bufferAfter: ScheduleMinutes
    let location: String?
    let travelMode: TravelMode
    let placement: SlotPlacement
    let allowReserved: Bool
    let overrun: ScheduleMinutes
    let preferences: [Preference]

    init(_ input: SlotRequirements, runtime: Scheduling.Runtime) throws {
        let duration = try parsed("duration_minutes") {
            try ScheduleMinutes.parse(input.duration_minutes, default: runtime.defaults.duration)
        }
        guard duration.raw > 0 else {
            throw Scheduling.InputFailure.invalid(field: "duration_minutes", reason: "must be greater than zero")
        }
        self.duration = duration
        let required = try runtime.participants(input.participants)
        self.required = required
        self.optional = try (input.optional_participants ?? [])
            .map { try runtime.participant($0) }
            .filter { !required.contains($0) }
        self.zone = try input.time_zone.map { zone in try parsed("time_zone") { try ScheduleTimeZone(zone) } }
            ?? runtime.defaults.timeZone
        self.workingHoursOnly = input.working_hours_only ?? true

        if input.earliest_time != nil || input.latest_time != nil {
            let from = input.earliest_time ?? "00:00"
            let to = input.latest_time ?? "24:00"
            self.timeOfDay = try parsed("earliest_time/latest_time") { try ClockRange(from: from, to: to) }
        } else {
            self.timeOfDay = nil
        }

        if let days = input.weekdays, !days.isEmpty {
            self.weekdays = Set(days)
        } else {
            self.weekdays = nil
        }
        self.bufferBefore = try parsed("buffer_before_minutes") {
            try ScheduleMinutes.parse(input.buffer_before_minutes, default: runtime.defaults.buffer)
        }
        self.bufferAfter = try parsed("buffer_after_minutes") {
            try ScheduleMinutes.parse(input.buffer_after_minutes, default: runtime.defaults.buffer)
        }
        self.location = input.location.flatMap { text in
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        self.travelMode = input.travel_mode ?? runtime.defaults.travelMode
        self.placement = input.placement ?? runtime.defaults.placement
        self.allowReserved = input.allow_reserved ?? false
        self.overrun = try parsed("overrun_minutes") { try ScheduleMinutes.parse(input.overrun_minutes, default: runtime.defaults.overrun) }

        let preferences = input.preferences ?? []
        var resolved: [Preference]
        if preferences.isEmpty {
            resolved = [.earlier(1)]
        } else {
            resolved = try preferences.enumerated().map { index, preference in
                let weight = preference.weight ?? 1
                guard weight > 0, weight.isFinite else {
                    throw Scheduling.InputFailure.invalid(field: "preferences[\(index)].weight", reason: "must be greater than zero")
                }
                switch preference.kind {
                case .earlier:
                    return .earlier(weight)
                case .later:
                    return .later(weight)
                case .avoid_back_to_back:
                    return .avoidBackToBack(weight)
                case .time_of_day:
                    guard let from = preference.from, let to = preference.to else {
                        throw Scheduling.InputFailure.invalid(field: "preferences[\(index)]", reason: "time_of_day needs from and to")
                    }
                    let range = try parsed("preferences[\(index)]") { try ClockRange(from: from, to: to) }
                    return .timeOfDay(range, weight)
                }
            }
        }
        let ownTimeOfDay = resolved.contains {
            if case .timeOfDay = $0 { return true }
            return false
        }
        if !ownTimeOfDay, let hours = runtime.defaults.preferredHours {
            resolved.append(.timeOfDay(hours, 1))
        }
        self.preferences = resolved
    }

    var everyone: [SchedulingParticipant] {
        required + optional
    }
}
