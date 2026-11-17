import Foundation

/// Finds overlaps, short buffers, overrun risk, impossible travel and
/// commitments in reserved time among existing events.
struct ConflictDetection {
    let buffer: ScheduleMinutes
    let oracle: TravelOracle

    func conflicts(in timeline: ParticipantTimeline) async -> [ScheduleConflict] {
        let participant = timeline.participant
        let zone = participant.timeZone
        let events = timeline.blocking.filter { !$0.isAllDay }
        var found: [ScheduleConflict] = []

        for (index, first) in events.enumerated() {
            // Every later event starting before this one ends overlaps it.
            for second in events[(index + 1)...] {
                guard second.interval.start < first.interval.end else {
                    break
                }
                found.append(conflict(.overlap, participant, first, second, zone: zone, required: nil, travel: nil))
            }

            // Events are sorted by start, so this is the immediately following
            // appointment; only same-day pairs need buffer or travel.
            guard
                let next = events[(index + 1)...].first(where: { $0.interval.start >= first.interval.end }),
                zone.sameDay(first.interval.end, next.interval.start)
            else {
                continue
            }
            let gap = wholeMinutes(next.interval.start.timeIntervalSince(first.interval.end))

            if let from = await oracle.place(of: first),
               let to = await oracle.place(of: next),
               let travel = await oracle.estimate(from: from, to: to, departing: first.interval.end),
               travel.minutes > gap
            {
                found.append(conflict(.travel_infeasible, participant, first, next, zone: zone, required: travel.minutes, travel: travel))
            } else if gap < buffer.raw {
                found.append(conflict(.insufficient_buffer, participant, first, next, zone: zone, required: buffer.raw, travel: nil))
            } else if gap < timeline.overrun(of: first).raw {
                found.append(conflict(.overrun_risk, participant, first, next, zone: zone, required: timeline.overrun(of: first).raw, travel: nil))
            }
        }

        for reservation in timeline.reserved {
            for commitment in timeline.blocking(overlapping: reservation.interval) {
                found.append(conflict(.in_reserved_time, participant, reservation, commitment, zone: zone, required: nil, travel: nil))
            }
        }
        return found
    }

    private func conflict(
        _ kind: ScheduleConflictKind,
        _ participant: SchedulingParticipant,
        _ first: ScheduledEvent,
        _ second: ScheduledEvent,
        zone: ScheduleTimeZone,
        required: Int?,
        travel: TravelEstimate?
    ) -> ScheduleConflict {
        let gapSeconds = second.interval.start.timeIntervalSince(first.interval.end)
        let gap = kind == .overlap || kind == .in_reserved_time
            ? -wholeMinutes(
                min(first.interval.end, second.interval.end)
                    .timeIntervalSince(max(first.interval.start, second.interval.start))
            )
            : wholeMinutes(gapSeconds)
        return .init(
            kind: kind,
            participant: participant.identifier,
            first: .init(first, in: zone),
            second: .init(second, in: zone),
            gap_minutes: gap,
            required_minutes: required,
            travel: travel
        )
    }
}
