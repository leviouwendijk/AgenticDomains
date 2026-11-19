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
        details: EventDetails = .none,
        participants: [SchedulingParticipant],
        zone: ScheduleTimeZone,
        overlaps: [String] = [],
        unstored: [String] = [],
        facts: [ReportBlock.Facts.Fact] = []
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
            notes: details.notes,
            recurrence: details.recurrence?.text,
            alerts: details.alerts.map(\.raw),
            travelMinutes: details.travel?.raw,
            url: details.url?.absoluteString,
            attachments: details.attachments.map(EventDetails.displayName),
            details: facts,
            warnings: overlaps.map { "Overlaps \($0)" } + unstored,
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

extension SchedulePresentation {
    /// The result of a calendar write, under the answer: the card the user
    /// approved, corrected with what was written. Without a review (an
    /// auto-approved call), the card is built from the written event alone.
    static func written(
        preflight: ToolPreflight?,
        title: String,
        start: String,
        end: String,
        calendar: String?,
        location: String?,
        change: ReportBlock.Event.Change
    ) -> ToolPresentation? {
        let approved = preflight?.preview.sections.lazy.compactMap { section -> ReportBlock.Event? in
            guard case .report(let document) = section.content,
                  case .event(let event)? = document.blocks.first else { return nil }
            return event
        }.first
        let interval = date(start).flatMap { from in
            date(end).map { ReportBlock.Event.Interval(start: from, end: $0) }
        } ?? approved?.interval
        guard let interval else { return nil }

        let event = ReportBlock.Event(
            title: title,
            interval: interval,
            timeZone: approved?.timeZone,
            allDay: approved?.allDay ?? false,
            change: change,
            previous: approved?.previous,
            calendar: calendar ?? approved?.calendar,
            location: location ?? approved?.location,
            attendees: approved?.attendees ?? [],
            notes: approved?.notes,
            recurrence: approved?.recurrence,
            alerts: approved?.alerts ?? [],
            travelMinutes: approved?.travelMinutes,
            url: approved?.url,
            attachments: approved?.attachments ?? [],
            details: approved?.details ?? [],
            warnings: approved?.warnings ?? [],
            context: approved?.context
        )
        return (try? ReportDocument(title: title, datasets: [], blocks: [.event(event)])).map {
            ToolPresentation($0, placement: .attachment)
        }
    }
}

public extension Scheduling.Tools.Book {
    func present(_ output: Output, input _: Input, preflight: ToolPreflight?) -> ToolPresentation? {
        SchedulePresentation.written(
            preflight: preflight, title: output.title, start: output.start, end: output.end,
            calendar: output.calendar, location: output.location, change: .create
        )
    }
}

public extension Scheduling.Tools.Update {
    func present(_ output: Output, input _: Input, preflight: ToolPreflight?) -> ToolPresentation? {
        SchedulePresentation.written(
            preflight: preflight, title: output.title, start: output.start, end: output.end,
            calendar: output.calendar, location: output.location, change: .update
        )
    }
}

public extension Scheduling.Tools.Remove {
    /// Only with the approved card: the output names the removed event as
    /// text, without its times.
    func present(_ output: Output, input _: Input, preflight: ToolPreflight?) -> ToolPresentation? {
        guard let preflight,
              case .report(let document)? = preflight.preview.sections.first?.content else { return nil }
        return ToolPresentation(document, placement: .attachment)
    }
}

extension EventDetails {
    /// An attachment by its file or page name.
    static func displayName(_ attachment: String) -> String {
        let name = (URL(string: attachment)?.scheme != nil ? URL(string: attachment)!.lastPathComponent : (attachment as NSString).lastPathComponent)
        return name.isEmpty ? attachment : name
    }
}

extension Scheduling.Runtime {
    /// Warnings for details `source` cannot store; they are not written.
    func unstored(_ requested: Set<EventDetail>, in source: any CalendarSource) -> [String] {
        EventDetail.allCases
            .filter { requested.contains($0) && !source.storedDetails.contains($0) }
            .map { "\(source.identifier) cannot store \($0.name); it will not be written" }
    }

    /// The details a book or update input asks for, validated.
    static func details(
        notes: String?,
        url: String?,
        alerts: [Int]?,
        travel: Int?,
        attachments: [String]?
    ) throws -> EventDetailsChange {
        var link: URL?
        if let text = url?.trimmedNonEmpty {
            guard let parsed = URL(string: text), parsed.scheme != nil else {
                throw Scheduling.EventWriteFailure.invalidURL(text)
            }
            link = parsed
        }
        return EventDetailsChange(
            notes: notes?.trimmedNonEmpty,
            url: link,
            alerts: try alerts.map { try Array(Set($0)).sorted().map { try ScheduleMinutes($0) } },
            travel: try travel.map { try ScheduleMinutes($0) },
            attachments: attachments.map { $0.compactMap(\.trimmedNonEmpty) }
        )
    }
}
