import Foundation
import Frame
import Primitives

/// A `scheduling.frame` document read into guaranteed values. Sources and
/// travel are the application's to supply when it builds the runtime.
public struct SchedulingConfiguration: Sendable {
    public enum Failure: Error, Sendable, LocalizedError {
        case invalid(field: String, reason: String)
        case conflictingCalendar(title: String, first: String, second: String)

        public var errorDescription: String? {
            switch self {
            case .invalid(let field, let reason):
                return "\(field): \(reason)"
            case .conflictingCalendar(let title, let first, let second):
                return "Calendar '\(title)' is declared twice, differently: \(first) and \(second)."
            }
        }
    }

    public let participants: [SchedulingParticipant]
    /// Calendars configured outside any participant.
    public let calendars: [CalendarPolicy]
    public let places: [(place: SchedulingPlace, aliases: [String])]
    public let defaults: Scheduling.Runtime.Defaults

    /// Parses and reads a document's source text.
    public init(source: String, filePath: String? = nil) throws {
        try self.init(
            document: Frame.parse(source, filePath: filePath, environment: SchedulingFrame.environment)
        )
    }

    public init(document: Frame.Document) throws {
        let settings: SchedulingFrame.Settings? = try document.binding(named: SchedulingFrame.settingsBinding).map { _ in
            try document.decode(SchedulingFrame.Settings.self, binding: SchedulingFrame.settingsBinding)
        }
        let defaults = try Self.defaults(settings)
        self.defaults = defaults

        var declared: [CalendarPolicy] = []
        func declare(_ spec: SchedulingFrame.Calendar, at field: String) throws -> CalendarPolicy {
            let policy = try Self.policy(spec, at: field)
            if let existing = declared.first(where: { $0.describesSameCalendar(as: policy) }) {
                guard existing == policy else {
                    throw Failure.conflictingCalendar(
                        title: existing.title,
                        first: Self.describe(existing),
                        second: Self.describe(policy)
                    )
                }
                return existing
            }
            declared.append(policy)
            return policy
        }

        for binding in document.bindings(ofType: "Calendar") {
            _ = try declare(try document.decode(SchedulingFrame.Calendar.self, binding: binding.name), at: binding.name)
        }
        for (index, spec) in (settings?.calendars ?? []).enumerated() {
            _ = try declare(spec, at: "\(SchedulingFrame.settingsBinding).calendars[\(index)]")
        }

        var participants: [SchedulingParticipant] = []
        for binding in document.bindings(ofType: "Participant") {
            let spec = try document.decode(SchedulingFrame.Participant.self, binding: binding.name)
            let calendars = try (spec.calendars ?? []).enumerated().map { index, calendar in
                try declare(calendar, at: "\(binding.name).calendars[\(index)]")
            }
            participants.append(.init(
                identifier: binding.name,
                name: spec.name ?? binding.name,
                timeZone: try spec.timeZone.map { zone in
                    try Self.field("\(binding.name).timeZone") { try ScheduleTimeZone(zone) }
                } ?? defaults.timeZone,
                workingHours: try spec.workingHours.map { try Self.workingHours($0, at: "\(binding.name).workingHours") } ?? .weekdays,
                calendars: calendars,
                home: spec.home.flatMap { text in
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? nil : trimmed
                },
                reservedHours: try spec.reservedHours.map { try Self.workingHours($0, at: "\(binding.name).reservedHours") }
                    ?? .init([:])
            ))
        }
        self.participants = participants
        self.calendars = declared.filter { policy in
            !participants.contains { $0.calendars.contains(policy) }
        }

        self.places = try document.bindings(ofType: "Place").map { binding in
            let spec = try document.decode(SchedulingFrame.Place.self, binding: binding.name)
            guard (-90...90).contains(spec.latitude), (-180...180).contains(spec.longitude) else {
                throw Failure.invalid(field: binding.name, reason: "latitude must be within ±90 and longitude within ±180")
            }
            return (
                SchedulingPlace(label: spec.label ?? binding.name, latitude: spec.latitude, longitude: spec.longitude),
                [binding.name] + (spec.aliases ?? [])
            )
        }
    }

    /// The runtime over the given sources. Known places resolve first, then
    /// `resolver` when given.
    public func runtime(
        sources: [any CalendarSource],
        resolver: (any PlaceResolver)? = nil,
        travel: any TravelEstimator = StraightLineTravelEstimator()
    ) -> Scheduling.Runtime {
        let known = StaticPlaceResolver(places)
        return .init(
            sources: sources,
            participants: participants,
            calendars: calendars,
            places: resolver.map { ChainedPlaceResolver([known, $0]) } ?? known,
            travel: travel,
            defaults: defaults
        )
    }

    // MARK: reading

    private static func defaults(_ settings: SchedulingFrame.Settings?) throws -> Scheduling.Runtime.Defaults {
        let at = SchedulingFrame.settingsBinding
        return .init(
            timeZone: try settings?.timeZone.map { zone in try field("\(at).timeZone") { try ScheduleTimeZone(zone) } }
                ?? .current(),
            buffer: try field("\(at).bufferMinutes") { try ScheduleMinutes.parse(settings?.bufferMinutes, default: .zero) },
            travelMode: settings?.travelMode ?? .driving,
            step: try settings?.stepMinutes.map { step in
                guard step >= 5 else {
                    throw Failure.invalid(field: "\(at).stepMinutes", reason: "must be at least 5")
                }
                return try field("\(at).stepMinutes") { try ScheduleMinutes(step) }
            },
            placement: settings?.placement ?? .prefer_offered,
            duration: try settings?.defaultDurationMinutes.map { minutes in
                guard minutes > 0 else {
                    throw Failure.invalid(field: "\(at).defaultDurationMinutes", reason: "must be greater than zero")
                }
                return try field("\(at).defaultDurationMinutes") { try ScheduleMinutes(minutes) }
            },
            overrun: try field("\(at).defaultOverrunMinutes") {
                try ScheduleMinutes.parse(settings?.defaultOverrunMinutes, default: .zero)
            },
            preferredHours: try settings?.preferredHours.map { try range($0, at: "\(at).preferredHours") },
            splitTravel: settings?.splitTravel ?? .avoid
        )
    }

    private static func policy(_ spec: SchedulingFrame.Calendar, at path: String) throws -> CalendarPolicy {
        guard !spec.title.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw Failure.invalid(field: "\(path).title", reason: "must not be empty")
        }
        return .init(
            spec.title,
            identifier: spec.identifier,
            role: spec.role ?? .commitments,
            allDayRole: spec.allDayRole,
            overrun: try field("\(path).overrunMinutes") { try ScheduleMinutes.parse(spec.overrunMinutes, default: .zero) },
            offerTitles: (spec.offerTitles ?? []).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
            sharedTravel: spec.sharedTravel ?? false
        )
    }

    private static func workingHours(_ week: SchedulingFrame.WorkingWeek, at path: String) throws -> WorkingHours {
        var ranges: [ScheduleWeekday: [ClockRange]] = [:]
        for day in ScheduleWeekday.allCases {
            ranges[day] = try week.ranges(on: day).enumerated().map { index, text in
                try range(text, at: "\(path).\(day.rawValue)[\(index)]")
            }
        }
        return .init(ranges)
    }

    /// `HH:mm-HH:mm`.
    private static func range(_ text: String, at path: String) throws -> ClockRange {
        let bounds = text.split(separator: "-", omittingEmptySubsequences: false)
        guard bounds.count == 2 else {
            throw Failure.invalid(field: path, reason: "'\(text)' is not a range such as 09:00-17:00")
        }
        return try field(path) {
            try ClockRange(
                from: bounds[0].trimmingCharacters(in: .whitespaces),
                to: bounds[1].trimmingCharacters(in: .whitespaces)
            )
        }
    }

    private static func field<Value>(_ path: String, _ body: () throws -> Value) throws -> Value {
        do {
            return try body()
        } catch let failure as InvarianceFailure {
            throw Failure.invalid(field: path, reason: failure.violations.map(\.message).joined(separator: "; "))
        }
    }

    private static func describe(_ policy: CalendarPolicy) -> String {
        "\(policy.role.rawValue)" + (policy.allDayRole.map { ", all-day \($0.rawValue)" } ?? "") + ", overrun \(policy.overrun.raw) min" + (policy.identifier.map { ", identifier \($0)" } ?? "")
    }
}
