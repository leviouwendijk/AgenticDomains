import Foundation

public extension Scheduling {
    /// Why a booking, change or removal could not be planned. Nothing has
    /// been written when one of these is thrown.
    enum EventWriteFailure: Error, Sendable, LocalizedError {
        case emptyTitle
        case unknownCalendar(String, known: [String])
        case ambiguousCalendar(String, sources: [String])
        case noDefaultCalendar(participants: [String], candidates: [String])
        case unbookableRole(calendar: String, role: CalendarRole)
        case eventNotFound(title: String, start: String)
        case ambiguousEvent(title: String, start: String, calendars: [String])
        case noOpenOffer(start: String)
        case ambiguousOffer(start: String, offers: [String])
        case unknownSource(String)
        case nothingToChange
        case invalidRecurrence(String)
        case invalidURL(String)

        public var errorDescription: String? {
            switch self {
            case .emptyTitle:
                return "An appointment needs a title."
            case .invalidRecurrence(let reason):
                return "The repetition cannot be written: \(reason)."
            case .invalidURL(let text):
                return "'\(text)' is not a URL."
            case .unknownCalendar(let name, let known):
                return "No calendar source shows a calendar '\(name)'. Known: \(known.joined(separator: ", "))."
            case .ambiguousCalendar(let name, let sources):
                return "Calendar '\(name)' exists in several sources (\(sources.joined(separator: ", "))); name it by identifier."
            case .noDefaultCalendar(let participants, let candidates):
                let options = candidates.isEmpty ? "none is configured" : "candidates: \(candidates.joined(separator: ", "))"
                return "No single commitments calendar is shared by \(participants.joined(separator: ", ")) (\(options)). Name the calendar."
            case .unbookableRole(let calendar, let role):
                return "Calendar '\(calendar)' is a \(role.rawValue) calendar; appointments go into a \(CalendarRole.commitments.rawValue) or \(CalendarRole.reserved.rawValue) calendar."
            case .eventNotFound(let title, let start):
                return "No event '\(title)' starts at \(start). Take the start and title from \(Scheduling.Tools.Agenda.identifier.rawValue)."
            case .ambiguousEvent(let title, let start, let calendars):
                return "Several events '\(title)' start at \(start) (calendars: \(calendars.joined(separator: ", "))); name the calendar."
            case .noOpenOffer(let start):
                return "No open offered slot covers the appointment at \(start)."
            case .ambiguousOffer(let start, let offers):
                return "Several offered slots cover the appointment at \(start): \(offers.joined(separator: "; "))."
            case .unknownSource(let source):
                return "Calendar source \(source) is not configured."
            case .nothingToChange:
                return "The change names nothing to change."
            }
        }
    }
}

extension Scheduling.Runtime {
    func source(named identifier: String) throws -> any CalendarSource {
        guard let source = sources.first(where: { $0.identifier == identifier }) else {
            throw Scheduling.EventWriteFailure.unknownSource(identifier)
        }
        return source
    }

    /// The named calendar, or the one commitments calendar every participant
    /// owns, provided its role is one of `roles`.
    func writableCalendar(
        _ name: String?,
        for participants: [SchedulingParticipant],
        roles: Set<CalendarRole> = [.commitments, .reserved]
    ) async throws -> (source: any CalendarSource, calendar: CalendarReference) {
        var visible: [(source: any CalendarSource, calendar: CalendarReference)] = []
        for source in sources {
            for calendar in try await source.calendars() {
                visible.append((source, calendar))
            }
        }

        let wanted: (CalendarReference) -> Bool
        let label: String
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            label = name
            wanted = { $0.identifier == name || $0.title.caseInsensitiveCompare(name) == .orderedSame }
        } else {
            let shared = calendars.filter { policy in
                policy.role == .commitments
                    && participants.allSatisfy { participant in
                        participant.calendars.contains { $0.describesSameCalendar(as: policy) }
                    }
            }
            guard shared.count == 1, let policy = shared.first else {
                throw Scheduling.EventWriteFailure.noDefaultCalendar(
                    participants: participants.map(\.identifier),
                    candidates: shared.map(\.label)
                )
            }
            label = policy.label
            wanted = policy.matches
        }

        let matches = visible.filter { wanted($0.calendar) }
        guard let match = matches.first else {
            throw Scheduling.EventWriteFailure.unknownCalendar(label, known: visible.map(\.calendar.title))
        }
        guard matches.count == 1 else {
            throw Scheduling.EventWriteFailure.ambiguousCalendar(label, sources: matches.map(\.source.identifier))
        }
        let role = policy(for: match.calendar).role
        guard roles.contains(role) else {
            throw Scheduling.EventWriteFailure.unbookableRole(calendar: match.calendar.title, role: role)
        }
        return match
    }

    /// The one event with this title starting at `start`, as the agenda
    /// lists it. Matching the occurrence's start keeps a change to one
    /// occurrence of a recurring event.
    func event(
        startingAt startText: String,
        title: String,
        calendar: String?
    ) async throws -> ScheduledEvent {
        let start = try ScheduleTimestamp.parse(startText, field: "event_start")
        let probe = try ScheduleInterval(start: start, end: start.addingTimeInterval(60))
        let wantedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = try await events(in: probe).filter { event in
            event.interval.start == start
                && event.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(wantedTitle) == .orderedSame
                && (calendar.map { name in
                    event.calendar.identifier == name
                        || event.calendar.title.caseInsensitiveCompare(name) == .orderedSame
                } ?? true)
        }
        guard let match = matches.first else {
            throw Scheduling.EventWriteFailure.eventNotFound(title: title, start: startText)
        }
        guard matches.count == 1 else {
            throw Scheduling.EventWriteFailure.ambiguousEvent(
                title: title,
                start: startText,
                calendars: matches.map(\.calendar.title)
            )
        }
        return match
    }

    /// Participants whose time the calendar represents; the primary one
    /// when nobody claims it.
    func owners(of calendar: CalendarReference) -> [SchedulingParticipant] {
        let owners = participants.filter { participant in
            participant.calendars.contains { $0.matches(calendar) }
        }
        return owners.isEmpty ? Array(participants.prefix(1)) : owners
    }

    /// The participant's open offered slot that holds `interval` entirely.
    func openOffer(
        holding interval: ScheduleInterval,
        for participants: [SchedulingParticipant],
        zone: ScheduleTimeZone
    ) async throws -> ScheduledEvent {
        let rendered = ScheduleTimestamp.render(interval.start, in: zone)
        var offers: [ScheduledEvent] = []
        for timeline in try await timelines(for: participants, in: interval) {
            for offer in timeline.offers where offer.interval.contains(interval) && !offers.contains(offer) {
                offers.append(offer)
            }
        }
        guard let offer = offers.first else {
            throw Scheduling.EventWriteFailure.noOpenOffer(start: rendered)
        }
        guard offers.count == 1 else {
            throw Scheduling.EventWriteFailure.ambiguousOffer(
                start: rendered,
                offers: offers.map { describe($0, in: zone) }
            )
        }
        return offer
    }

    /// What the participants already have at that time, as lines for an
    /// approval and a result. `excluding` leaves out the event being moved.
    func overlaps(
        _ interval: ScheduleInterval,
        for participants: [SchedulingParticipant],
        zone: ScheduleTimeZone,
        excluding excluded: ScheduledEvent? = nil
    ) async throws -> [String] {
        var lines: [String] = []
        for timeline in try await timelines(for: participants, in: interval) {
            let who = timeline.participant.name
            for event in timeline.blocking(overlapping: interval) + timeline.reserved(overlapping: interval)
            where event != excluded {
                lines.append("\(who): \(describe(event, in: zone))")
            }
            if !timeline.participant.reservedHours(overlapping: interval).isEmpty {
                lines.append("\(who): reserved hours")
            }
        }
        return lines
    }

    func describe(_ event: ScheduledEvent, in zone: ScheduleTimeZone) -> String {
        let from = ScheduleTimestamp.render(event.interval.start, in: zone)
        let to = ScheduleTimestamp.render(event.interval.end, in: zone)
        return "\(event.title) (\(event.calendar.title), \(from) – \(to))"
    }
}

extension String {
    /// Trimmed, or `nil` when nothing is left.
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
