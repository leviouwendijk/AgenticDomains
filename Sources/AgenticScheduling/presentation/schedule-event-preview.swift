import Agentic
import Foundation
import Reporting

extension Scheduling.Runtime {
    /// What a calendar write is approved from: the event as a card, what it
    /// runs into, and the day around it in the calendars of the people it is
    /// for. Book, change and remove all show this card.
    func eventPreview(
        title: String,
        interval: ScheduleInterval,
        allDay: Bool = false,
        change: ReportBlock.Event.Change,
        previous: ScheduleInterval? = nil,
        calendar: String,
        location: String? = nil,
        notes: String? = nil,
        participants: [SchedulingParticipant],
        zone: ScheduleTimeZone,
        overlaps: [String] = [],
        details: [ReportBlock.Facts.Fact] = []
    ) async throws -> ToolPreflight.Preview {
        let event = ReportBlock.Event(
            title: title,
            interval: .init(start: interval.start, end: interval.end),
            timeZone: zone.raw,
            allDay: allDay,
            change: change,
            previous: previous.map { .init(start: $0.start, end: $0.end) },
            calendar: calendar,
            location: location,
            attendees: participants.map(\.name),
            notes: notes,
            details: details,
            warnings: overlaps.map { "Overlaps \($0)" },
            context: allDay ? nil : try await day(around: [interval] + (previous.map { [$0] } ?? []), change: change, participants: participants, zone: zone)
        )
        let document = try ReportDocument(title: title, datasets: [], blocks: [.event(event)])
        return .init([.report(document, title: "Event")])
    }

    /// Two hours either side of the event, whole hours, one lane per person
    /// and one for the event itself.
    private func day(
        around intervals: [ScheduleInterval],
        change: ReportBlock.Event.Change,
        participants: [SchedulingParticipant],
        zone: ScheduleTimeZone
    ) async throws -> ReportBlock.Timeline? {
        guard !participants.isEmpty,
              let first = intervals.map(\.start).min(),
              let last = intervals.map(\.end).max() else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone.timeZone
        let from = calendar.dateInterval(of: .hour, for: first.addingTimeInterval(-2 * 3600))?.start ?? first
        let after = last.addingTimeInterval(2 * 3600)
        let hour = calendar.dateInterval(of: .hour, for: after)
        let to = hour.map { $0.start == after ? after : $0.end } ?? after
        let window = try ScheduleInterval(start: from, end: to)

        var lanes = try await timelines(for: participants, in: window).map { timeline in
            SchedulePresentation.lane(
                timeline.participant.name,
                Scheduling.Tools.Busy.busy(timeline, in: window)
            )
        }
        let label = change == .cancel ? "Removed" : change == .update ? "Changed" : "New"
        lanes.append(.init(label: label, spans: [
            .init(start: intervals[0].start, end: intervals[0].end, mark: .highlight),
        ]))
        return .init(start: from, end: to, timeZone: zone.raw, lanes: lanes)
    }
}
