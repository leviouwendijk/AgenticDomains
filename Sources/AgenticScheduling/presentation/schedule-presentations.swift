import Agentic
import DSL
import Foundation
import Reporting
import Search

// What the user sees for each scheduling tool. The proposal is the answer
// and sits with it; the rest are working results, shown with their call.

public extension Scheduling.Tools.Propose {
    func present(_ output: Output, input _: Input) -> ToolPresentation? {
        let zone = SchedulePresentation.zone(output.time_zone)
        let recommendation = output.recommendation
        var blocks: [ReportBlock] = []

        var facts: [ReportBlock.Facts.Fact] = [
            .init("Recommended", SchedulePresentation.span(recommendation.start, recommendation.end, zone: zone)),
            .init("Placement", SchedulePresentation.placement(recommendation.placement)),
            .init("Score", SchedulePresentation.percent(recommendation.score)),
            .init("Attending", output.participants.joined(separator: ", ")),
        ]
        if !output.optional_participants.isEmpty {
            let missing = recommendation.optional_unavailable
            facts.append(.init(
                "Optional",
                output.optional_participants.map { missing.contains($0) ? "\($0) (unavailable)" : $0 }
                    .joined(separator: ", ")
            ))
        }
        if let interpretation = output.interpretation {
            facts.append(.init("Read as", interpretation))
        }
        blocks.append(.facts(.init(facts: facts)))
        if let note = recommendation.note {
            blocks.append(.narrative(.paragraph([.text(note)])))
        }

        if !recommendation.feasible {
            blocks.append(.callout(.init(
                tone: .failure,
                title: "The recommendation does not fit",
                content: SchedulePresentation.list(recommendation.violations.map(\.detail))
            )))
        }
        if recommendation.placement == .reserved {
            blocks.append(.callout(.init(
                tone: .warning,
                title: "Escalation",
                content: .paragraph([.text("This opens reserved time; it needs your approval.")])
            )))
        }
        if let timeline = SchedulePresentation.timeline(output, zone: zone) {
            blocks.append(.timeline(timeline))
        }
        if !output.alternatives.isEmpty {
            blocks.append(.table(.init(
                dataset: "options",
                columns: ["option", "when", "placement", "score", "fits", "trade-off"],
                title: "Options"
            )))
        }
        if !recommendation.terms.isEmpty {
            blocks.append(.table(.init(dataset: "terms", columns: ["preference", "weight", "met"], title: "Why \(recommendation.label) scores \(SchedulePresentation.percent(recommendation.score))")))
        }
        let notes = output.information_gaps + output.assumptions
        if !notes.isEmpty {
            blocks.append(.callout(.init(
                tone: .info,
                title: "Check",
                content: SchedulePresentation.list(notes)
            )))
        }

        let options = ([recommendation] + output.alternatives).map { option in
            ReportDataset.Row(values: [
                .text(option.label),
                .text(SchedulePresentation.span(option.start, option.end, zone: zone)),
                .text(SchedulePresentation.placement(option.placement)),
                .decimal(SchedulePresentation.decimal(option.score)),
                .boolean(option.feasible),
                .text(option.note ?? ""),
            ])
        }
        let terms = recommendation.terms.map { term in
            ReportDataset.Row(values: [
                .text(term.kind.rawValue.replacingOccurrences(of: "_", with: " ") + (term.detail.map { " (\($0))" } ?? "")),
                .decimal(SchedulePresentation.decimal(term.weight)),
                .decimal(SchedulePresentation.decimal(term.satisfaction)),
            ])
        }
        let datasets = [
            try? ReportDataset(
                id: "options",
                columns: [
                    .init("option", kind: .text), .init("when", kind: .text), .init("placement", kind: .text),
                    .init("score", kind: .decimal), .init("fits", kind: .boolean), .init("trade-off", kind: .text),
                ],
                rows: options,
                coverage: .complete
            ),
            try? ReportDataset(
                id: "terms",
                columns: [.init("preference", kind: .text), .init("weight", kind: .decimal), .init("met", kind: .decimal)],
                rows: terms,
                coverage: .complete
            ),
        ].compactMap { $0 }

        return (try? ReportDocument(title: output.title, datasets: datasets, blocks: blocks)).map {
            ToolPresentation($0)
        }
    }
}

public extension Scheduling.Tools.Availability {
    /// The grid sits with the answer: it is what the user asked to see.
    func present(_ output: Output, input _: Input) -> ToolPresentation? {
        let zone = SchedulePresentation.zone(output.time_zone)
        var facts: [ReportBlock.Facts.Fact] = [
            .init("Who", output.participants.joined(separator: ", ")),
            .init("Length", "\(output.duration_minutes) min"),
            .init("Window", SchedulePresentation.window(output.window_start, output.window_end, zone: zone)),
            .init("Rows", "\(output.clean) ✓ fits · \(output.escalation) ⚠ needs escalation · \(output.blocked) ✗ does not fit"),
        ]
        if let location = output.location { facts.insert(.init("Where", location), at: 2) }
        var blocks: [ReportBlock] = [.facts(.init(facts: facts))]
        let columns = ["fit", "when"] + output.participants + ["why"]
        if output.rows.isEmpty {
            blocks.append(.callout(.init(tone: .warning, title: "Nothing fits", content: .paragraph([.text("No start time fits in this window, even with escalation.")]))))
        } else {
            blocks.append(.table(.init(dataset: "grid", columns: columns)))
        }
        let notes = output.information_gaps + (output.omitted > 0 ? ["\(output.omitted) more rows left out."] : [])
        if !notes.isEmpty {
            blocks.append(.callout(.init(tone: .info, title: "Check", content: SchedulePresentation.list(notes))))
        }
        let rows = output.rows.map { row -> ReportDataset.Row in
            let why: [String]
            switch row.status {
            case .clean: why = row.offered_starts.isEmpty ? ["open time"] : ["offered: " + row.offered_starts.joined(separator: ", ")]
            case .escalation: why = row.escalations
            case .blocked: why = row.reasons
            }
            let cells = output.participants.map { name -> StructuredValue? in
                let entries = row.cells.first { $0.participant == name }?.entries ?? []
                return .text(entries.isEmpty ? "free" : entries.joined(separator: "\n"))
            }
            return .init(values: [.text(row.status.symbol), .text(SchedulePresentation.when(row, days: output.rows_kind == .days, zone: zone))] + cells + [.text(why.joined(separator: "\n"))])
        }
        let dataset = try? ReportDataset(
            id: "grid",
            columns: columns.map { .init($0, kind: .text) },
            rows: rows,
            coverage: output.omitted > 0 ? .partial(offset: 0, total: output.rows.count + output.omitted) : .complete
        )
        return (try? ReportDocument(title: output.title, datasets: dataset.map { [$0] } ?? [], blocks: blocks)).map {
            ToolPresentation($0)
        }
    }
}

public extension Scheduling.Tools.Busy {
    func present(_ output: Output, input _: Input) -> ToolPresentation? {
        guard let start = try? ScheduleTimestamp.parse(output.window_start, field: "window_start"),
              let end = try? ScheduleTimestamp.parse(output.window_end, field: "window_end"),
              start < end else { return nil }
        let zone = SchedulePresentation.zone(output.participants.first?.time_zone)
        let timeline = ReportBlock.Timeline(
            start: start,
            end: end,
            timeZone: zone.identifier,
            lanes: output.participants.map { SchedulePresentation.lane($0.participant, $0) }
        )
        let facts = output.participants.map {
            ReportBlock.Facts.Fact($0.participant, "\(SchedulePresentation.hours($0.busy_minutes)) busy, \($0.open_offers.count) open offers")
        }
        var blocks: [ReportBlock] = [.timeline(timeline)]
        if !facts.isEmpty { blocks.insert(.facts(.init(facts: facts)), at: 0) }
        return (try? ReportDocument(title: "Busy time", datasets: [], blocks: blocks)).map {
            ToolPresentation($0, placement: .inspector)
        }
    }
}

public extension Scheduling.Tools.Agenda {
    func present(_ output: Output, input _: Input) -> ToolPresentation? {
        guard let start = SchedulePresentation.date(output.window_start),
              let end = SchedulePresentation.date(output.window_end),
              start < end else { return nil }
        let zone = SchedulePresentation.zone(output.participants.first?.time_zone)
        // All-day and marked-free entries would only cover the lane; they
        // stay in the list below.
        let lanes = output.participants.map { agenda in
            ReportBlock.Timeline.Lane(
                label: agenda.participant,
                spans: agenda.entries.compactMap { entry -> ReportBlock.Timeline.Span? in
                    guard !entry.all_day,
                          let mark = SchedulePresentation.mark(entry.reading),
                          let from = SchedulePresentation.date(entry.start),
                          let to = SchedulePresentation.date(entry.end) else { return nil }
                    return .init(start: from, end: to, mark: mark, label: entry.title)
                }
            )
        }
        var blocks: [ReportBlock] = [.timeline(.init(start: start, end: end, timeZone: zone.identifier, lanes: lanes))]
        let unplaced = output.participants.flatMap { agenda in
            agenda.entries.filter { $0.all_day || SchedulePresentation.mark($0.reading) == nil }.map {
                "\(agenda.participant): \($0.title) (\($0.all_day ? "all day" : $0.reading.rawValue.replacingOccurrences(of: "_", with: " ")))"
            }
        }
        if !unplaced.isEmpty {
            blocks.append(.callout(.init(tone: .info, title: "Not on the timeline", content: SchedulePresentation.list(unplaced))))
        }
        let notes = output.information_gaps
            + output.participants.filter { $0.omitted > 0 }.map { "\($0.participant): \($0.omitted) entries left out" }
        if !notes.isEmpty {
            blocks.append(.callout(.init(tone: .info, title: "Gaps", content: SchedulePresentation.list(notes))))
        }
        return (try? ReportDocument(title: "Agenda", datasets: [], blocks: blocks)).map {
            ToolPresentation($0, placement: .inspector)
        }
    }
}

public extension Scheduling.Tools.FindSlots {
    func present(_ output: Output, input _: Input) -> ToolPresentation? {
        let zone = SchedulePresentation.zone(output.time_zone)
        var blocks: [ReportBlock] = [.facts(.init(facts: [
            .init("Candidates", "\(output.candidates.count) of \(output.candidates_considered) start times considered"),
            .init("Excluded by", output.rejected.isEmpty
                ? "nothing"
                : output.rejected.map { "\($0.constraint.rawValue.replacingOccurrences(of: "_", with: " ")) \($0.count)" }.joined(separator: ", ")),
        ]))]
        let rows = output.candidates.map { candidate in
            ReportDataset.Row(values: [
                .text(SchedulePresentation.span(candidate.start, candidate.end, zone: zone)),
                .text(SchedulePresentation.placement(candidate.placement)),
                .decimal(SchedulePresentation.decimal(candidate.score)),
                .text(candidate.optional_unavailable.joined(separator: ", ")),
            ])
        }
        if !rows.isEmpty {
            blocks.append(.table(.init(dataset: "candidates", columns: ["when", "placement", "score", "optional missing"])))
        }
        if !output.information_gaps.isEmpty {
            blocks.append(.callout(.init(tone: .info, title: "Gaps", content: SchedulePresentation.list(output.information_gaps))))
        }
        let dataset = try? ReportDataset(
            id: "candidates",
            columns: [
                .init("when", kind: .text), .init("placement", kind: .text),
                .init("score", kind: .decimal), .init("optional missing", kind: .text),
            ],
            rows: rows,
            coverage: .complete
        )
        return (try? ReportDocument(title: "Slot search", datasets: dataset.map { [$0] } ?? [], blocks: blocks)).map {
            ToolPresentation($0, placement: .inspector)
        }
    }
}

public extension Scheduling.Tools.Evaluate {
    func present(_ output: Output, input _: Input) -> ToolPresentation? {
        let zone = SchedulePresentation.zone(nil)
        var blocks: [ReportBlock] = [.facts(.init(facts: [
            .init("Time", SchedulePresentation.span(output.start, output.end, zone: zone)),
            .init("Fits", output.feasible ? "yes" : "no"),
            .init("Placement", SchedulePresentation.placement(output.placement)),
            .init("Score", SchedulePresentation.percent(output.score)),
        ]))]
        if !output.violations.isEmpty {
            blocks.append(.callout(.init(tone: .failure, title: "Violations", content: SchedulePresentation.list(output.violations.map(\.detail)))))
        }
        if !output.information_gaps.isEmpty {
            blocks.append(.callout(.init(tone: .info, title: "Gaps", content: SchedulePresentation.list(output.information_gaps))))
        }
        return (try? ReportDocument(title: "Evaluation", datasets: [], blocks: blocks)).map {
            ToolPresentation($0, placement: .inspector)
        }
    }
}

public extension Scheduling.Tools.Conflicts {
    func present(_ output: Output, input _: Input) -> ToolPresentation? {
        let zone = SchedulePresentation.zone(nil)
        let rows = output.conflicts.map { conflict in
            ReportDataset.Row(values: [
                .text(conflict.participant),
                .text(conflict.kind.rawValue.replacingOccurrences(of: "_", with: " ")),
                .text("\(conflict.first.title) → \(conflict.second.title)"),
                .text(SchedulePresentation.span(conflict.first.end, conflict.second.start, zone: zone)),
                .integer(Int64(conflict.gap_minutes)),
                conflict.required_minutes.map { .integer(Int64($0)) },
            ])
        }
        var blocks: [ReportBlock] = [.facts(.init(facts: [
            .init("Conflicts", "\(output.conflicts.count) among \(output.events_considered) events"),
        ]))]
        if !rows.isEmpty {
            blocks.append(.table(.init(dataset: "conflicts", columns: ["who", "kind", "between", "gap at", "gap", "needed"])))
        }
        if !output.information_gaps.isEmpty {
            blocks.append(.callout(.init(tone: .info, title: "Gaps", content: SchedulePresentation.list(output.information_gaps))))
        }
        let dataset = try? ReportDataset(
            id: "conflicts",
            columns: [
                .init("who", kind: .text), .init("kind", kind: .text), .init("between", kind: .text),
                .init("gap at", kind: .text), .init("gap", kind: .integer), .init("needed", kind: .integer),
            ],
            rows: rows,
            coverage: .complete
        )
        return (try? ReportDocument(title: "Conflicts", datasets: dataset.map { [$0] } ?? [], blocks: blocks)).map {
            ToolPresentation($0, placement: .inspector)
        }
    }
}

enum SchedulePresentation {
    static func zone(_ identifier: String?) -> TimeZone {
        identifier.flatMap(TimeZone.init(identifier:)) ?? .current
    }

    static func date(_ value: String) -> Date? {
        try? ScheduleTimestamp.parse(value, field: "time")
    }

    /// `Tue 24 Nov 10:00–11:00`, or both dates when the span crosses midnight.
    static func span(_ start: String, _ end: String, zone: TimeZone) -> String {
        guard let from = date(start), let to = date(end) else { return "\(start) – \(end)" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let day = formatter("EEE d MMM HH:mm", zone: zone)
        let time = formatter("HH:mm", zone: zone)
        let sameDay = calendar.isDate(from, inSameDayAs: to.addingTimeInterval(-1))
        return day.string(from: from) + "–" + (sameDay ? time : day).string(from: to)
    }

    static func formatter(_ format: String, zone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = zone
        formatter.dateFormat = format
        return formatter
    }

    /// A grid row's time: `Thu 19 Nov 14:30–19:00 · starts 14:30–17:30`;
    /// a day row is the day and its starts, `Tue 24 Nov · starts 09:30–11:15, 14:00`.
    static func when(_ row: Scheduling.Tools.Availability.Row, days: Bool, zone: TimeZone) -> String {
        guard let from = date(row.start) else { return row.start }
        let day = formatter("EEE d MMM", zone: zone).string(from: from)
        if row.starts.isEmpty { return day }
        if days { return day + " · starts " + row.starts.joined(separator: ", ") }
        let span = span(row.start, row.end, zone: zone)
        let single = row.starts.count == 1 && !row.starts[0].contains("–")
        return single ? span : span + " · starts " + row.starts.joined(separator: ", ")
    }

    /// A window of whole days as days, `Mon 23 Nov – Sun 6 Dec`; otherwise
    /// as a span.
    static func window(_ start: String, _ end: String, zone: TimeZone) -> String {
        guard let from = date(start), let to = date(end) else { return "\(start) – \(end)" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        guard calendar.startOfDay(for: from) == from, calendar.startOfDay(for: to) == to else {
            return span(start, end, zone: zone)
        }
        let days = formatter("EEE d MMM", zone: zone)
        let last = to.addingTimeInterval(-1)
        return calendar.isDate(from, inSameDayAs: last)
            ? days.string(from: from)
            : days.string(from: from) + " – " + days.string(from: last)
    }

    static func placement(_ kind: SlotPlacementKind) -> String {
        switch kind {
        case .offered: "in an offered slot"
        case .open: "open time"
        case .reserved: "reserved time (escalation)"
        }
    }

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    static func hours(_ minutes: Int) -> String {
        minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h\(String(format: "%02d", minutes % 60))"
    }

    /// Two decimals, exact: scores are ratios, not money.
    static func decimal(_ value: Double) -> Decimal {
        Decimal(string: String(format: "%.2f", value)) ?? .zero
    }

    static func mark(_ reading: AgendaReading) -> ReportBlock.Timeline.Mark? {
        switch reading {
        case .blocking, .provisional: .occupied
        case .reserved: .reserved
        case .offer: .available
        case .marked_free, .record: nil
        }
    }

    static func list(_ items: [String]) -> StructuredContent {
        .list(style: .unordered, items: items.map { .paragraph([.text($0)]) })
    }

    static func lane(_ label: String, _ busy: ParticipantBusy) -> ReportBlock.Timeline.Lane {
        func spans(_ blocks: [BusyBlock], _ mark: ReportBlock.Timeline.Mark) -> [ReportBlock.Timeline.Span] {
            blocks.compactMap { block in
                guard let start = date(block.start), let end = date(block.end) else { return nil }
                return .init(start: start, end: end, mark: mark, label: block.events.isEmpty ? nil : block.events.joined(separator: ", "))
            }
        }
        return .init(
            label: label,
            spans: spans(busy.open_offers, .available) + spans(busy.reserved, .reserved) + spans(busy.blocks, .occupied)
        )
    }

    /// Each participant's calendar, then a lane with the options marked.
    static func timeline(_ output: Scheduling.Tools.Propose.Output, zone: TimeZone) -> ReportBlock.Timeline? {
        guard let start = date(output.view_start), let end = date(output.view_end) else { return nil }
        let names = output.participants + output.optional_participants.map { "\($0) (optional)" }
        var lanes = output.calendars.enumerated().map { index, busy in
            lane(index < names.count ? names[index] : busy.participant, busy)
        }
        let options = ([output.recommendation] + output.alternatives).compactMap { option -> ReportBlock.Timeline.Span? in
            guard let from = date(option.start), let to = date(option.end) else { return nil }
            let label = option.label == "A" ? "A · recommended" : option.label
            return .init(start: from, end: to, mark: .highlight, label: option.feasible ? label : "\(label) · does not fit")
        }
        lanes.append(.init(label: "Options", spans: options))
        return .init(start: start, end: end, timeZone: zone.identifier, lanes: lanes)
    }
}
