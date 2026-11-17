import Foundation

/// Checks and scores candidate appointments against resolved requirements
/// and the participants' timelines.
struct SlotEvaluator: Sendable {
    struct Assessment: Sendable {
        let violations: [SlotViolation]
        let travel: [TravelLeg]
        let placement: SlotPlacementKind
    }

    struct Search: Sendable {
        let candidates: [SlotCandidate]
        let rejected: [SlotRejection]
        /// Start times excluded by reserved time alone: what escalation opens.
        let reservedOnly: Int
        let considered: Int
        let truncated: Bool
    }

    /// Upper bound on candidate start times examined in one search.
    static let maximumCandidates = 10_000

    /// Margin at which back-to-back and overrun terms are fully satisfied.
    static let breathingRoom: TimeInterval = 30 * 60

    let requirements: ResolvedRequirements
    let window: ScheduleInterval
    let required: [ParticipantTimeline]
    let optional: [ParticipantTimeline]
    let meeting: SchedulingPlace?
    let oracle: TravelOracle

    /// Fetches timelines a day beyond the window on both sides, so adjacent
    /// appointments still count for buffers and travel at its edges.
    static func prepare(
        _ requirements: ResolvedRequirements,
        window: ScheduleInterval,
        runtime: Scheduling.Runtime
    ) async throws -> SlotEvaluator {
        let day = try ScheduleMinutes(24 * 60)
        let timelines = try await runtime.timelines(
            for: requirements.everyone,
            in: window.padded(before: day, after: day)
        )
        let oracle = TravelOracle(
            resolver: runtime.places,
            estimator: runtime.travel,
            mode: requirements.travelMode
        )
        var meeting: SchedulingPlace?
        if let location = requirements.location, case .resolved(let place) = await oracle.place(location) {
            meeting = place
        }
        return .init(
            requirements: requirements,
            window: window,
            required: Array(timelines.prefix(requirements.required.count)),
            optional: Array(timelines.dropFirst(requirements.required.count)),
            meeting: meeting,
            oracle: oracle
        )
    }

    /// Required participants whose offered slots matter for placement.
    var offering: [ParticipantTimeline] {
        requirements.placement == .any ? [] : required.filter(\.offersSlots)
    }

    // MARK: search

    func search(step: ScheduleMinutes, limit: Int) async throws -> Search {
        let duration = requirements.duration.seconds
        let starts = candidateStarts(step: step.seconds)
        var feasible: [(slot: ScheduleInterval, assessment: Assessment)] = []
        var rejections: [SlotConstraintKind: Int] = [:]
        var reservedOnly = 0

        for start in starts.prefix(Self.maximumCandidates) {
            let slot = try ScheduleInterval(start: start, end: start.addingTimeInterval(duration))
            let assessment = await assess(slot)
            let kinds = Set(assessment.violations.map(\.constraint))
            if kinds.isEmpty {
                feasible.append((slot, assessment))
            } else {
                for kind in kinds {
                    rejections[kind, default: 0] += 1
                }
                if kinds == [.reserved] {
                    reservedOnly += 1
                }
            }
        }

        let ranked = feasible
            .map { entry in (entry, score(entry.slot)) }
            .sorted { lhs, rhs in
                lhs.1.score != rhs.1.score
                    ? lhs.1.score > rhs.1.score
                    : lhs.0.slot.start < rhs.0.slot.start
            }

        // Distinct alternatives: never two candidates that overlap.
        var picked: [SlotCandidate] = []
        var taken: [ScheduleInterval] = []
        for (entry, scored) in ranked where picked.count < limit {
            guard !taken.contains(where: { $0.overlaps(entry.slot) }) else {
                continue
            }
            taken.append(entry.slot)
            picked.append(candidate(entry.slot, assessment: entry.assessment, scored: scored))
        }

        return .init(
            candidates: picked,
            rejected: SlotConstraintKind.allCases.compactMap { kind in
                rejections[kind].map { SlotRejection(constraint: kind, count: $0) }
            },
            reservedOnly: reservedOnly,
            considered: min(starts.count, Self.maximumCandidates),
            truncated: starts.count > Self.maximumCandidates
        )
    }

    func candidate(_ slot: ScheduleInterval, assessment: Assessment, scored: (score: Double, terms: [SlotScoreTerm])) -> SlotCandidate {
        let attendance = optionalAttendance(slot)
        return .init(
            start: ScheduleTimestamp.render(slot.start, in: requirements.zone),
            end: ScheduleTimestamp.render(slot.end, in: requirements.zone),
            placement: assessment.placement,
            score: scored.score,
            terms: scored.terms,
            optional_available: attendance.available,
            optional_unavailable: attendance.unavailable,
            travel: assessment.travel
        )
    }

    /// Step-aligned times from local midnight, plus the start of every
    /// offered slot, since offers rarely sit on the grid.
    private func candidateStarts(step: TimeInterval) -> [Date] {
        let duration = requirements.duration.seconds
        let midnight = requirements.zone.calendar.startOfDay(for: window.start)
        let offset = window.start.timeIntervalSince(midnight)
        var start = midnight.addingTimeInterval((offset / step).rounded(.up) * step)
        var starts: Set<Date> = []
        while start.addingTimeInterval(duration) <= window.end, starts.count <= Self.maximumCandidates {
            starts.insert(start)
            start = start.addingTimeInterval(step)
        }
        for offer in offering.flatMap(\.offers) where offer.interval.start >= window.start {
            if offer.interval.start.addingTimeInterval(duration) <= window.end {
                starts.insert(offer.interval.start)
            }
        }
        return starts.sorted()
    }

    // MARK: hard constraints

    func assess(_ slot: ScheduleInterval) async -> Assessment {
        var violations: [SlotViolation] = []
        var legs: [TravelLeg] = []
        var opensReserved = false
        let zone = requirements.zone

        if !window.contains(slot) {
            violations.append(.init(constraint: .window, participant: nil, detail: "Outside the requested window."))
        }

        if let weekdays = requirements.weekdays {
            let day = ScheduleWeekday.of(slot.start, in: zone)
            if !weekdays.contains(day) {
                violations.append(.init(constraint: .weekday, participant: nil, detail: "Falls on \(day.rawValue)."))
            }
        }

        if let range = requirements.timeOfDay, !Self.fits(slot, in: [range], zone: zone) {
            violations.append(.init(
                constraint: .time_of_day,
                participant: nil,
                detail: "Not within \(range.from.raw)-\(range.to.raw) \(zone.raw)."
            ))
        }

        for timeline in required {
            let participant = timeline.participant
            if requirements.workingHoursOnly, !Self.withinWorkingHours(slot, participant) {
                violations.append(.init(
                    constraint: .working_hours,
                    participant: participant.identifier,
                    detail: "Outside working hours in \(participant.timeZone.raw)."
                ))
            }

            let overlapping = timeline.blocking(overlapping: slot)
            if !overlapping.isEmpty {
                violations.append(.init(
                    constraint: .busy,
                    participant: participant.identifier,
                    detail: "Busy: \(Self.titles(overlapping))."
                ))
            } else {
                let padded = slot.padded(before: requirements.bufferBefore, after: requirements.bufferAfter)
                let near = timeline.blocking(overlapping: padded)
                if !near.isEmpty {
                    violations.append(.init(
                        constraint: .buffer,
                        participant: participant.identifier,
                        detail: "Within the \(requirements.bufferBefore.raw)/\(requirements.bufferAfter.raw) minute buffer of: \(Self.titles(near))."
                    ))
                }
            }

            let reservations = timeline.reserved(overlapping: slot)
            if !reservations.isEmpty {
                if requirements.allowReserved {
                    opensReserved = true
                } else {
                    violations.append(.init(
                        constraint: .reserved,
                        participant: participant.identifier,
                        detail: "Reserved: \(Self.titles(reservations))."
                    ))
                }
            }

            if requirements.placement == .offered_only, timeline.offersSlots, !timeline.isOffered(slot) {
                violations.append(.init(
                    constraint: .not_offered,
                    participant: participant.identifier,
                    detail: "No offered slot covers this time."
                ))
            }

            if let meeting {
                let travel = await travelChecks(slot, timeline: timeline, meeting: meeting)
                violations += travel.violations
                legs += travel.legs
            }
        }

        let placement: SlotPlacementKind
        if opensReserved {
            placement = .reserved
        } else if required.contains(where: { $0.isOffered(slot) }) {
            placement = .offered
        } else {
            placement = .open
        }
        return .init(violations: violations, travel: legs, placement: placement)
    }

    private func travelChecks(
        _ slot: ScheduleInterval,
        timeline: ParticipantTimeline,
        meeting: SchedulingPlace
    ) async -> (violations: [SlotViolation], legs: [TravelLeg]) {
        let participant = timeline.participant
        var violations: [SlotViolation] = []
        var legs: [TravelLeg] = []

        if let previous = Self.previous(before: slot, in: timeline),
           let origin = await oracle.place(of: previous),
           let estimate = await oracle.estimate(from: origin, to: meeting, departing: previous.interval.end)
        {
            let available = wholeMinutes(slot.start.timeIntervalSince(previous.interval.end))
            legs.append(.init(participant: participant.identifier, from: previous.title, to: meeting.label, estimate: estimate, available_minutes: available))
            if estimate.minutes > available {
                violations.append(.init(
                    constraint: .travel_before,
                    participant: participant.identifier,
                    detail: "Needs \(estimate.minutes) min from '\(previous.title)'; \(available) available."
                ))
            }
        }

        if let next = Self.next(after: slot, in: timeline),
           let destination = await oracle.place(of: next),
           let estimate = await oracle.estimate(from: meeting, to: destination, departing: slot.end)
        {
            let available = wholeMinutes(next.interval.start.timeIntervalSince(slot.end))
            legs.append(.init(participant: participant.identifier, from: meeting.label, to: next.title, estimate: estimate, available_minutes: available))
            if estimate.minutes > available {
                violations.append(.init(
                    constraint: .travel_after,
                    participant: participant.identifier,
                    detail: "Needs \(estimate.minutes) min to '\(next.title)'; \(available) available."
                ))
            }
        }

        return (violations, legs)
    }

    /// The timed commitment ending last before the slot, on the same day.
    static func previous(before slot: ScheduleInterval, in timeline: ParticipantTimeline) -> ScheduledEvent? {
        let zone = timeline.participant.timeZone
        return timeline.blocking
            .filter { !$0.isAllDay && $0.interval.end <= slot.start && zone.sameDay($0.interval.end, slot.start) }
            .max { $0.interval.end < $1.interval.end }
    }

    /// The timed commitment starting first after the slot, on the same day.
    static func next(after slot: ScheduleInterval, in timeline: ParticipantTimeline) -> ScheduledEvent? {
        let zone = timeline.participant.timeZone
        return timeline.blocking
            .filter { !$0.isAllDay && $0.interval.start >= slot.end && zone.sameDay(slot.end, $0.interval.start) }
            .min { $0.interval.start < $1.interval.start }
    }

    static func withinWorkingHours(_ slot: ScheduleInterval, _ participant: SchedulingParticipant) -> Bool {
        let day = ScheduleWeekday.of(slot.start, in: participant.timeZone)
        return fits(slot, in: participant.workingHours.ranges(on: day), zone: participant.timeZone)
    }

    /// Whether the slot lies inside one of the ranges on its start day.
    static func fits(_ slot: ScheduleInterval, in ranges: [ClockRange], zone: ScheduleTimeZone) -> Bool {
        let from = zone.minutes(of: slot.start, since: slot.start)
        let to = zone.minutes(of: slot.end, since: slot.start)
        return ranges.contains { from >= $0.from.minuteOfDay && to <= $0.to.minuteOfDay }
    }

    private static func titles(_ events: [ScheduledEvent]) -> String {
        events.map(\.title).joined(separator: ", ")
    }

    // MARK: soft preferences

    func score(_ slot: ScheduleInterval) -> (score: Double, terms: [SlotScoreTerm]) {
        var terms: [SlotScoreTerm] = requirements.preferences.map { preference in
            switch preference {
            case .earlier(let weight):
                return term(.earlier, nil, weight, earliness(slot))
            case .later(let weight):
                return term(.later, nil, weight, 1 - earliness(slot))
            case .timeOfDay(let range, let weight):
                return term(.time_of_day, "\(range.from.raw)-\(range.to.raw)", weight, timeOfDay(slot, range))
            case .avoidBackToBack(let weight):
                return term(.avoid_back_to_back, nil, weight, breathingRoom(slot))
            }
        }
        if requirements.placement == .prefer_offered, !offering.isEmpty {
            let covered = offering.filter { $0.isOffered(slot) }.count
            terms.append(term(.offered_slot, nil, 2, Double(covered) / Double(offering.count)))
        }
        // Scored for every candidate once overruns apply at all, so the
        // term never favours the candidates it happens to touch.
        if requirements.overrun > .zero || required.contains(where: \.hasOverruns) {
            let margin = overrunMargin(slot)
            terms.append(term(.overrun_margin, margin?.detail, 1, margin?.satisfaction ?? 1))
        }
        if !optional.isEmpty {
            let attendance = optionalAttendance(slot)
            terms.append(term(.optional_attendance, nil, 1, Double(attendance.available.count) / Double(optional.count)))
        }
        let total = terms.reduce(0) { $0 + $1.weight }
        let weighted = terms.reduce(0) { $0 + $1.weight * $1.satisfaction }
        return (total > 0 ? Self.rounded(weighted / total) : 1, terms)
    }

    private func term(_ kind: SlotScoreTermKind, _ detail: String?, _ weight: Double, _ satisfaction: Double) -> SlotScoreTerm {
        .init(kind: kind, detail: detail, weight: weight, satisfaction: Self.rounded(min(1, max(0, satisfaction))))
    }

    private func earliness(_ slot: ScheduleInterval) -> Double {
        let span = window.seconds - slot.seconds
        guard span > 0 else {
            return 1
        }
        return 1 - slot.start.timeIntervalSince(window.start) / span
    }

    private func timeOfDay(_ slot: ScheduleInterval, _ range: ClockRange) -> Double {
        let zone = requirements.zone
        let from = zone.minutes(of: slot.start, since: slot.start)
        let to = zone.minutes(of: slot.end, since: slot.start)
        let distance = max(range.from.minuteOfDay - from, to - range.to.minuteOfDay, 0)
        return 1 - Double(distance) / 180
    }

    /// Full marks at 30 minutes or more from every required participant's busy time.
    private func breathingRoom(_ slot: ScheduleInterval) -> Double {
        let gaps = required.flatMap(\.busy).compactMap { busy -> TimeInterval? in
            if busy.overlaps(slot) {
                return 0
            }
            let gap = busy.end <= slot.start
                ? slot.start.timeIntervalSince(busy.end)
                : busy.start.timeIntervalSince(slot.end)
            return gap < 12 * 3600 ? gap : nil
        }
        guard let nearest = gaps.min() else {
            return 1
        }
        return nearest / Self.breathingRoom
    }

    /// How much of the usual overrun fits: of the previous commitment into
    /// this slot, and of this appointment into the next commitment. `nil`
    /// when no overrun applies on either side of this slot.
    private func overrunMargin(_ slot: ScheduleInterval) -> (satisfaction: Double, detail: String)? {
        var worst: (satisfaction: Double, detail: String)?
        func consider(_ gap: TimeInterval, _ overrun: ScheduleMinutes, _ detail: String) {
            guard overrun > .zero else {
                return
            }
            let satisfaction = gap / overrun.seconds
            if let current = worst, current.satisfaction <= satisfaction {
                return
            }
            worst = (satisfaction, detail)
        }
        for timeline in required {
            if let previous = Self.previous(before: slot, in: timeline) {
                let overrun = timeline.overrun(of: previous)
                consider(slot.start.timeIntervalSince(previous.interval.end), overrun, "'\(previous.title)' often runs \(overrun.raw) min over")
            }
            if let next = Self.next(after: slot, in: timeline) {
                consider(next.interval.start.timeIntervalSince(slot.end), requirements.overrun, "may run \(requirements.overrun.raw) min into '\(next.title)'")
            }
        }
        return worst
    }

    func optionalAttendance(_ slot: ScheduleInterval) -> (available: [String], unavailable: [String]) {
        var available: [String] = []
        var unavailable: [String] = []
        for timeline in optional {
            let free = !timeline.isBusy(during: slot)
                && timeline.reserved(overlapping: slot).isEmpty
                && (!requirements.workingHoursOnly || Self.withinWorkingHours(slot, timeline.participant))
            if free {
                available.append(timeline.participant.identifier)
            } else {
                unavailable.append(timeline.participant.identifier)
            }
        }
        return (available, unavailable)
    }

    static func rounded(_ value: Double) -> Double {
        (value * 1000).rounded() / 1000
    }
}
