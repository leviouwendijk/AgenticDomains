import Agentic
import Foundation
import Macros
import Schema

/// How a row of the availability grid fits.
@JSONSchema
public enum AvailabilityStatus: String, Sendable, Codable, Hashable, CaseIterable {
    /// Fits without escalation.
    case clean
    /// Fits only by opening reserved time or splitting a shared trip.
    case escalation
    /// Does not fit.
    case blocked

    var symbol: String {
        switch self {
        case .clean: "✓"
        case .escalation: "⚠"
        case .blocked: "✗"
        }
    }
}

/// Which rows the grid has.
@JSONSchema
public enum AvailabilityRows: String, Sendable, Codable, Hashable, CaseIterable {
    /// Every stretch of start times that fits, with or without escalation.
    case candidates
    /// Every day of the window, also the days that do not fit, with why.
    case days
}

public extension Scheduling.Tools {
    /// The overview the user reads when they want every possibility: one row
    /// per stretch of start times (or per day, or per given start), one
    /// column per participant with what they have around it, and a mark
    /// for whether it fits. Everything in it is computed here.
    @Tool("availability")
    struct Availability {
        @JSONSchema
        public struct Input: HashableSource {
            /// Earliest possible start, ISO 8601 with offset.
            public let window_start: String
            /// Latest possible end, ISO 8601 with offset.
            public let window_end: String
            /// The appointment's requirements, as for `schedule_tool_find_slots`.
            /// Reserved time and split trips are always checked as
            /// escalations (⚠), whatever `allow_reserved` and
            /// `allow_split_travel` say.
            public let requirements: SlotRequirements
            /// `candidates` (default): every stretch of start times that
            /// fits. `days`: every day of the window, also those that do not
            /// fit.
            public let rows: AvailabilityRows?
            /// Check exactly these starts (ISO 8601 with offset) instead,
            /// one row each.
            public let starts: [String]?
            /// Granularity of start times, at least 5. Defaults to the
            /// configured step.
            public let step_minutes: Int?
            /// How far before and after each row its participants' events
            /// are shown, within the same day. Default 120. Day rows show
            /// the whole day.
            public let context_minutes: Int?
            /// Leave out stretches that need escalation. Default false.
            public let clean_only: Bool?
            /// Maximum rows, 1...60. Default 40.
            public let limit: Int?

            public init(
                window_start: String,
                window_end: String,
                requirements: SlotRequirements,
                rows: AvailabilityRows? = nil,
                starts: [String]? = nil,
                step_minutes: Int? = nil,
                context_minutes: Int? = nil,
                clean_only: Bool? = nil,
                limit: Int? = nil
            ) {
                self.window_start = window_start
                self.window_end = window_end
                self.requirements = requirements
                self.rows = rows
                self.starts = starts
                self.step_minutes = step_minutes
                self.context_minutes = context_minutes
                self.clean_only = clean_only
                self.limit = limit
            }
        }

        @JSONSchema
        public struct Cell: HashableResult {
            public let participant: String
            /// What the participant has around the row, in time order, such
            /// as `11:00–12:30 Client | Dog [A]`, `10:00–21:00 reserved` (weekly
            /// reserved hours), `reserved: Office day`
            /// or `13:00–14:30 offered: Slot 2`.
            public let entries: [String]
        }

        @JSONSchema
        public struct Row: HashableResult {
            public let status: AvailabilityStatus
            /// The stretch the row covers: first start to last end.
            public let start: String
            public let end: String
            /// Start times that fit, as `HH:mm` or `HH:mm–HH:mm`, in the
            /// requirements' zone. Empty for a row that does not fit.
            public let starts: [String]
            /// Starts inside an offered slot.
            public let offered_starts: [String]
            /// What escalation the row needs, such as opening reserved hours.
            public let escalations: [String]
            /// Why it does not fit, per participant where it applies.
            public let reasons: [String]
            public let cells: [Cell]
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let title: String
            public let time_zone: String
            public let window_start: String
            public let window_end: String
            public let rows_kind: AvailabilityRows
            public let duration_minutes: Int
            public let participants: [String]
            public let location: String?
            public let rows: [Row]
            public let clean: Int
            public let escalation: Int
            public let blocked: Int
            /// Rows left out beyond the limit.
            public let omitted: Int
            public let information_gaps: [String]
        }

        public static let purpose =
            "Show the user an availability grid: one row per stretch of start times that fits (or per day with `rows: days`, or per given start), a column per participant listing their events, reserved hours and offered slots around it, and a mark: ✓ fits, ⚠ fits only with escalation (named), ✗ does not fit (with why). Use it for \"all possibilities\", \"why not that day\" and per-person overviews; the user sees the grid, you read a summary."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func preflight(_ input: Input, in _: CapabilityContext) async throws -> ToolPreflight {
            let who = input.requirements.participants?.joined(separator: ", ") ?? "the primary participant"
            let rows = input.starts.map { "\($0.count) given starts" } ?? (input.rows == .days ? "days" : "fitting stretches")
            return .init(
                tool: Self.definition.identifier,
                risk: Self.definition.risk,
                summary: "Availability grid for \(who), \(input.window_start.prefix(10)) to \(input.window_end.prefix(10)), by \(rows)",
                sideEffects: []
            )
        }

        public func call(_ input: Input, in context: CapabilityContext) async throws -> Output {
            let runtime = try Scheduling.runtime(in: context)
            let window = try ScheduleTimestamp.window(start: input.window_start, end: input.window_end)
            let given = try ResolvedRequirements(input.requirements, runtime: runtime)
            // Escalations are always weighed, so the grid shows what they open.
            var requirements = given
            requirements.allowReserved = true
            requirements.allowSplitTravel = true
            let step = try parsed("step_minutes") {
                try ScheduleMinutes.parse(input.step_minutes, default: runtime.defaults.step)
            }
            guard step.raw >= 5 else {
                throw Scheduling.InputFailure.invalid(field: "step_minutes", reason: "must be at least 5")
            }
            let context = try parsed("context_minutes") { try ScheduleMinutes.parse(input.context_minutes, default: ScheduleMinutes(120)) }
            let limit = min(max(input.limit ?? 40, 1), 60)
            let kind = input.starts == nil ? input.rows ?? .candidates : .candidates

            let evaluator = try await SlotEvaluator.prepare(requirements, window: window, runtime: runtime)
            let grid = Grid(evaluator: evaluator, given: given, context: context.seconds, step: step.seconds)

            var rows: [Row]
            if let starts = input.starts {
                rows = []
                for (index, text) in starts.enumerated() {
                    let start = try ScheduleTimestamp.parse(text, field: "starts[\(index)]")
                    let slot = try ScheduleInterval(start: start, end: start.addingTimeInterval(requirements.duration.seconds))
                    let judgement = await grid.judge(slot)
                    rows.append(try grid.row([(slot, judgement)], day: false))
                }
            } else {
                let judged = try await grid.judgeAll(grid.starts(in: window, step: step.seconds))
                rows = kind == .days
                    ? try grid.days(judged, window: window)
                    : try grid.runs(judged, step: step.seconds)
            }
            if input.clean_only == true {
                rows = rows.filter { $0.status == .clean }
            }

            var gaps = await evaluator.oracle.gaps + FindSlots.visibilityGaps(requirements)
            if kind == .candidates, input.starts == nil, rows.isEmpty {
                gaps.append("No start time fits in the window, even with escalation; ask with rows: days to see why each day fails.")
            }
            return .init(
                title: "Availability",
                time_zone: requirements.zone.raw,
                window_start: input.window_start,
                window_end: input.window_end,
                rows_kind: input.starts == nil ? kind : .candidates,
                duration_minutes: requirements.duration.raw,
                participants: requirements.required.map(\.name),
                location: requirements.location,
                rows: Array(rows.prefix(limit)),
                clean: rows.filter { $0.status == .clean }.count,
                escalation: rows.filter { $0.status == .escalation }.count,
                blocked: rows.filter { $0.status == .blocked }.count,
                omitted: max(rows.count - limit, 0),
                information_gaps: gaps
            )
        }

        /// The model reads the marks and why, one line per row; the user
        /// reads the grid with everyone's events.
        public func render(_ output: Output, input _: Input) -> String? {
            let zone = SchedulePresentation.zone(output.time_zone)
            var lines = ["Availability grid shown to the user (\(output.participants.joined(separator: ", ")), \(output.duration_minutes) min): \(output.clean) ✓, \(output.escalation) ⚠, \(output.blocked) ✗."]
            for row in output.rows {
                var line = "\(row.status.symbol) " + SchedulePresentation.when(row, days: output.rows_kind == .days, zone: zone)
                let why = row.status == .blocked ? row.reasons : row.escalations
                if !why.isEmpty { line += " — " + why.joined(separator: "; ") }
                lines.append(line)
            }
            if output.omitted > 0 { lines.append("\(output.omitted) more rows left out; narrow the window or raise the limit.") }
            if !output.information_gaps.isEmpty { lines.append("Gaps: " + output.information_gaps.joined(separator: " ")) }
            return lines.joined(separator: "\n")
        }
    }
}

/// Judging start times and laying them out as rows.
struct Grid: Sendable {
    struct Judgement: Sendable {
        let slot: ScheduleInterval
        let status: AvailabilityStatus
        let offered: Bool
        let escalations: [String]
        let reasons: [String]
    }

    let evaluator: SlotEvaluator
    /// The requirements as asked, for which escalations they already allow.
    let given: ResolvedRequirements
    let context: TimeInterval
    /// Starts further apart than this begin a new stretch.
    let step: TimeInterval

    var zone: ScheduleTimeZone { evaluator.requirements.zone }

    /// Step-aligned starts plus every offered slot's start.
    func starts(in window: ScheduleInterval, step: TimeInterval) -> [Date] {
        let duration = evaluator.requirements.duration.seconds
        let midnight = zone.calendar.startOfDay(for: window.start)
        var start = midnight.addingTimeInterval((window.start.timeIntervalSince(midnight) / step).rounded(.up) * step)
        var starts: Set<Date> = []
        while start.addingTimeInterval(duration) <= window.end, starts.count < SlotEvaluator.maximumCandidates {
            starts.insert(start)
            start = start.addingTimeInterval(step)
        }
        for offer in evaluator.required.flatMap(\.offers)
        where offer.interval.start >= window.start && offer.interval.start.addingTimeInterval(duration) <= window.end {
            starts.insert(offer.interval.start)
        }
        return starts.sorted()
    }

    func judgeAll(_ starts: [Date]) async throws -> [Judgement] {
        var result: [Judgement] = []
        for start in starts {
            let slot = try ScheduleInterval(start: start, end: start.addingTimeInterval(evaluator.requirements.duration.seconds))
            result.append(await judge(slot))
        }
        return result
    }

    func judge(_ slot: ScheduleInterval) async -> Judgement {
        let assessment = await evaluator.assess(slot)
        let names = Dictionary(
            evaluator.requirements.everyone.map { ($0.identifier, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )
        let reasons = Self.unique(assessment.violations.map { violation in
            violation.participant.map { "\(names[$0] ?? $0): \(violation.detail)" } ?? violation.detail
        })
        var escalations: [String] = []
        if assessment.placement == .reserved {
            for timeline in evaluator.required where !timeline.isOffered(slot) {
                let reservations = SlotEvaluator.reservations(slot, in: timeline)
                if !reservations.isEmpty {
                    escalations.append("opens \(timeline.participant.name)'s " + reservations.joined(separator: ", "))
                }
            }
        }
        if evaluator.requirements.splitTravel == .avoid {
            for split in evaluator.splits(slot) {
                escalations.append("second car: splits a shared trip \(split.description)")
            }
        }
        let status: AvailabilityStatus = !reasons.isEmpty ? .blocked : escalations.isEmpty ? .clean : .escalation
        return .init(
            slot: slot,
            status: status,
            offered: assessment.placement == .offered,
            escalations: escalations,
            reasons: reasons
        )
    }

    /// Consecutive fitting starts with the same mark and escalations, per
    /// day, as one row each.
    func runs(_ judged: [Judgement], step: TimeInterval) throws -> [Scheduling.Tools.Availability.Row] {
        var groups: [[Judgement]] = []
        for judgement in judged where judgement.status != .blocked {
            if let last = groups.last?.last,
               last.status == judgement.status,
               Set(last.escalations.map(Self.kind)) == Set(judgement.escalations.map(Self.kind)),
               zone.sameDay(last.slot.start, judgement.slot.start),
               judgement.slot.start.timeIntervalSince(last.slot.start) <= step {
                groups[groups.count - 1].append(judgement)
            } else {
                groups.append([judgement])
            }
        }
        return try groups.map { group in try row(group.map { ($0.slot, $0) }, day: false) }
    }

    /// One row per day of the window: the best mark among its starts.
    func days(_ judged: [Judgement], window: ScheduleInterval) throws -> [Scheduling.Tools.Availability.Row] {
        var order: [Date] = []
        var byDay: [Date: [Judgement]] = [:]
        for judgement in judged {
            let day = zone.calendar.startOfDay(for: judgement.slot.start)
            if byDay[day] == nil { order.append(day) }
            byDay[day, default: []].append(judgement)
        }
        return try order.map { day in
            let all = byDay[day] ?? []
            let best: AvailabilityStatus = all.contains { $0.status == .clean } ? .clean
                : all.contains { $0.status == .escalation } ? .escalation : .blocked
            let chosen = best == .blocked ? all : all.filter { $0.status == best }
            return try row(chosen.map { ($0.slot, $0) }, day: true)
        }
    }

    func row(_ entries: [(ScheduleInterval, Judgement)], day: Bool) throws -> Scheduling.Tools.Availability.Row {
        let judgements = entries.map(\.1)
        let first = judgements.first!
        let status = judgements.map(\.status).contains(.clean) ? AvailabilityStatus.clean
            : judgements.map(\.status).contains(.escalation) ? .escalation : .blocked
        let fitting = judgements.filter { $0.status != .blocked }
        let start = (fitting.first ?? first).slot.start
        let end = (fitting.last ?? judgements.last!).slot.end
        let span: ScheduleInterval
        if day {
            let midnight = zone.calendar.startOfDay(for: first.slot.start)
            span = try ScheduleInterval(start: midnight, end: zone.calendar.date(byAdding: .day, value: 1, to: midnight) ?? end)
        } else {
            span = try ScheduleInterval(start: start.addingTimeInterval(-context), end: end.addingTimeInterval(context))
        }
        return .init(
            status: status,
            start: ScheduleTimestamp.render(start, in: zone),
            end: ScheduleTimestamp.render(end, in: zone),
            starts: Self.ranges(fitting.map(\.slot.start), step: step, zone: zone),
            offered_starts: fitting.filter(\.offered).map { Self.clock($0.slot.start, zone: zone) },
            escalations: Self.unique(fitting.flatMap(\.escalations)),
            // A day that does not fit says its most frequent reasons.
            reasons: status == .blocked ? Self.frequent(judgements.flatMap(\.reasons), limit: day ? 4 : 6) : [],
            cells: evaluator.required.map { cell($0, around: span, day: first.slot.start) }
        )
    }

    /// The participant's events, reserved hours and open offers that touch
    /// `span` on the row's day.
    func cell(_ timeline: ParticipantTimeline, around span: ScheduleInterval, day: Date) -> Scheduling.Tools.Availability.Cell {
        let calendar = zone.calendar
        let midnight = calendar.startOfDay(for: day)
        let next = calendar.date(byAdding: .day, value: 1, to: midnight) ?? span.end
        guard let bounds = try? ScheduleInterval(start: max(span.start, midnight), end: min(span.end, next)) else {
            return .init(participant: timeline.participant.name, entries: [])
        }
        var items: [(start: Date, text: String)] = []
        func add(_ event: ScheduledEvent, _ prefix: String) {
            guard event.interval.overlaps(bounds) else { return }
            let text = event.isAllDay
                ? "all day: \(prefix)\(event.title)"
                : "\(Self.clock(event.interval.start, zone: zone))–\(Self.clock(event.interval.end, zone: zone)) \(prefix)\(event.title)"
            items.append((event.isAllDay ? midnight : event.interval.start, text))
        }
        timeline.blocking.forEach { add($0, "") }
        timeline.reserved.forEach { add($0, "reserved: ") }
        timeline.offers.filter { !timeline.isBusy(during: $0.interval) }.forEach { add($0, "offered: ") }
        let dayWindow = (try? ScheduleInterval(start: midnight, end: next)) ?? bounds
        for interval in timeline.participant.reservedIntervals(in: dayWindow) where interval.overlaps(bounds) {
            items.append((interval.start, "\(Self.clock(interval.start, zone: zone))–\(Self.clock(interval.end, zone: zone)) reserved"))
        }
        let entries = items.sorted { $0.start < $1.start }.map(\.text)
        return .init(participant: timeline.participant.name, entries: entries)
    }

    /// Each stretch of consecutive starts: `11:00`, or `14:30–17:30`.
    static func ranges(_ starts: [Date], step: TimeInterval, zone: ScheduleTimeZone) -> [String] {
        var stretches: [[Date]] = []
        for start in starts {
            if let last = stretches.last?.last, start.timeIntervalSince(last) <= step {
                stretches[stretches.count - 1].append(start)
            } else {
                stretches.append([start])
            }
        }
        return stretches.map { stretch in
            stretch.count == 1
                ? clock(stretch[0], zone: zone)
                : "\(clock(stretch[0], zone: zone))–\(clock(stretch.last!, zone: zone))"
        }
    }

    static func clock(_ date: Date, zone: ScheduleTimeZone) -> String {
        SchedulePresentation.formatter("HH:mm", zone: zone.timeZone).string(from: date)
    }

    /// The kind of an escalation, so runs do not break on its details.
    static func kind(_ escalation: String) -> String {
        escalation.hasPrefix("second car") ? "second car" : String(escalation.prefix { $0 != "(" })
    }

    static func unique(_ items: [String]) -> [String] {
        var seen: Set<String> = []
        return items.filter { seen.insert($0).inserted }
    }

    static func frequent(_ items: [String], limit: Int) -> [String] {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for item in items {
            if counts[item] == nil { order.append(item) }
            counts[item, default: 0] += 1
        }
        let ranked = order.enumerated().sorted { lhs, rhs in
            counts[lhs.element]! != counts[rhs.element]! ? counts[lhs.element]! > counts[rhs.element]! : lhs.offset < rhs.offset
        }
        return Array(ranked.map(\.element).prefix(limit))
    }
}
