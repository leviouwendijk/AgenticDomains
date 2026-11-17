import Agentic
import AgenticScheduling
import Foundation
import Testing

private typealias F = SchedulingFixture

private func times(_ candidates: [SlotCandidate]) -> [String] {
    candidates.map { String($0.start.dropFirst(11).prefix(5)) }
}

enum SchedulingInvariantTests {
    static func run() throws {
        let nine = F.date("2026-11-23T09:00:00+01:00")
        try Expect.throwsError("Empty interval") { _ = try ScheduleInterval(start: nine, end: nine) }
        try Expect.throwsError("Hour 25") { _ = try ClockTime("25:00") }
        try Expect.throwsError("Single-digit hour") { _ = try ClockTime("9:00") }
        try Expect.throwsError("24:30") { _ = try ClockTime("24:30") }
        try Expect.equal(try ClockTime("24:00").minuteOfDay, 1440, "End of day")
        try Expect.throwsError("Inverted range") { _ = try ClockRange(from: "10:00", to: "09:00") }
        try Expect.throwsError("Negative minutes") { _ = try ScheduleMinutes(-1) }
        try Expect.throwsError("Unknown zone") { _ = try ScheduleTimeZone("Mars/Olympus_Mons") }

        let merged = ScheduleInterval.merged([
            try ScheduleInterval(start: F.date("2026-11-23T09:30:00+01:00"), end: F.date("2026-11-23T11:00:00+01:00")),
            try ScheduleInterval(start: nine, end: F.date("2026-11-23T10:00:00+01:00")),
            try ScheduleInterval(start: F.date("2026-11-23T11:00:00+01:00"), end: F.date("2026-11-23T11:30:00+01:00")),
            try ScheduleInterval(start: F.date("2026-11-23T12:00:00+01:00"), end: F.date("2026-11-23T13:00:00+01:00")),
        ])
        try Expect.equal(merged.count, 2, "Overlapping and touching intervals merge")
        try Expect.equal(merged.first?.minutes, 150, "First merged block spans 09:00-11:30")
    }
}

enum SchedulingBusyTests {
    static func run() async throws {
        let context = try F.context()
        let day = try await Scheduling.Tools.Busy().call(
            .init(window_start: F.monday.start, window_end: F.monday.end, participants: ["levi"]),
            in: context
        )
        let levi = try requireFirst(day.participants)
        try Expect.equal(levi.blocks.map(\.events), [["Standup"], ["Client visit"]], "Free all-day event does not block")
        try Expect.equal(levi.busy_minutes, 120, "Two busy hours")
        try Expect.equal(levi.blocks.first?.start, "2026-11-23T09:00:00+01:00", "Rendered in participant zone")

        let clipped = try await Scheduling.Tools.Busy().call(
            .init(window_start: "2026-11-23T09:30:00+01:00", window_end: "2026-11-23T13:30:00+01:00"),
            in: context
        )
        try Expect.equal(try requireFirst(clipped.participants).busy_minutes, 60, "Blocks clipped to the window; primary by default")
    }
}

enum SchedulingSlotTests {
    static func find(_ requirements: SlotRequirements, window: (start: String, end: String) = F.monday, step: Int = 30, limit: Int = 3) async throws -> Scheduling.Tools.FindSlots.Output {
        try await Scheduling.Tools.FindSlots().call(
            .init(window_start: window.start, window_end: window.end, requirements: requirements, step_minutes: step, limit: limit),
            in: try F.context()
        )
    }

    static func basic() async throws {
        let result = try await find(.init(duration_minutes: 60, participants: ["levi", "Anna"]))
        try Expect.equal(times(result.candidates), ["11:00", "12:00", "14:00"], "Earliest distinct free hours for both")
        try Expect.equal(result.time_zone, "Europe/Amsterdam", "Default zone")
        let rejected = result.rejected.map(\.constraint)
        try Expect.contains(rejected, .busy, "Busy time rejected candidates")
        try Expect.contains(rejected, .working_hours, "Working hours rejected candidates")
    }

    static func buffers() async throws {
        let result = try await find(.init(
            duration_minutes: 60,
            participants: ["levi", "anna"],
            buffer_before_minutes: 15,
            buffer_after_minutes: 15
        ))
        try Expect.equal(times(result.candidates), ["11:30", "14:30", "15:30"], "Fifteen minutes kept around each slot")
        try Expect.contains(result.rejected.map(\.constraint), .buffer, "Buffer rejections counted")
    }

    static func preferences() async throws {
        let result = try await find(.init(
            duration_minutes: 60,
            preferences: [
                .init(kind: .time_of_day, weight: 2, from: "14:00", to: "16:00"),
                .init(kind: .earlier),
            ]
        ))
        try Expect.equal(times(result.candidates).first, "14:00", "Preferred afternoon wins")
        let top = try requireFirst(result.candidates)
        try Expect.equal(top.terms.map(\.kind), [.time_of_day, .earlier], "Breakdown names each term")
        try Expect.equal(top.terms.first?.detail, "14:00-16:00", "Range given as detail")
        try Expect.true(top.score > 0.6 && top.score < 1, "Weighted mean of full afternoon and partial earliness")
    }

    static func optionalAttendance() async throws {
        let result = try await find(
            .init(duration_minutes: 60, optional_participants: ["sam"]),
            step: 60,
            limit: 10
        )
        let byTime = Dictionary(uniqueKeysWithValues: result.candidates.map { (String($0.start.dropFirst(11).prefix(5)), $0) })
        try Expect.equal(byTime["10:00"]?.optional_available, ["sam"], "Sam free at ten")
        try Expect.equal(byTime["11:00"]?.optional_unavailable, ["sam"], "Sam busy at eleven")
        try Expect.true((byTime["10:00"]?.score ?? 0) > (byTime["11:00"]?.score ?? 1), "Optional attendance raises the score")
    }

    static func nothingFits() async throws {
        let result = try await find(
            .init(duration_minutes: 60),
            window: ("2026-11-28T00:00:00+01:00", "2026-11-29T00:00:00+01:00")
        )
        try Expect.equal(result.candidates.count, 0, "Saturday is outside working hours")
        try Expect.equal(result.rejected.map(\.constraint), [.working_hours], "Only working hours blocked")
    }

    static func unknownParticipant() async throws {
        do {
            _ = try await find(.init(duration_minutes: 30, participants: ["zed"]))
        } catch let failure as Scheduling.Runtime.Failure {
            guard case .unknownParticipant("zed", _) = failure else {
                throw failure
            }
            return
        }
        try Expect.true(false, "Unknown participant must throw")
    }
}

enum SchedulingTravelTests {
    static func evaluate(_ start: String) async throws -> Scheduling.Tools.Evaluate.Output {
        try await Scheduling.Tools.Evaluate().call(
            .init(start: start, requirements: .init(duration_minutes: 60, location: "office")),
            in: try F.context()
        )
    }

    static func evaluate() async throws {
        let tooClose = try await evaluate("2026-11-23T11:00:00+01:00")
        try Expect.false(tooClose.feasible, "An hour is not enough to reach Utrecht")
        try Expect.equal(tooClose.violations.map(\.constraint), [.travel_after], "Only travel after is violated")
        let leg = try requireFirst(tooClose.travel)
        try Expect.equal(leg.available_minutes, 60, "Gap until the client visit")
        try Expect.true(leg.estimate.minutes > 60 && leg.estimate.minutes < 80, "Straight-line driving estimate")

        let rightAfter = try await evaluate("2026-11-23T14:00:00+01:00")
        try Expect.equal(rightAfter.violations.map(\.constraint), [.travel_before], "No time to drive back")

        let later = try await evaluate("2026-11-23T15:30:00+01:00")
        try Expect.true(later.feasible, "Ninety minutes is enough")
        try Expect.equal(later.end, "2026-11-23T16:30:00+01:00", "End follows duration")
    }

    static func estimate() async throws {
        let context = try F.context()
        let known = try await Scheduling.Tools.EstimateTravel().call(
            .init(origin: "  Kantoor ", destination: "utrecht client", travel_mode: .cycling),
            in: context
        )
        try Expect.equal(known.estimate?.method, .straight_line, "Estimated without routing")
        try Expect.equal(known.estimate?.mode, .cycling, "Requested mode")
        try Expect.true((known.estimate?.minutes ?? 0) > 150, "Cycling 34 km takes hours")

        let unknown = try await Scheduling.Tools.EstimateTravel().call(
            .init(origin: "office", destination: "the moon"),
            in: context
        )
        try Expect.isNil(unknown.estimate, "No estimate for an unresolved place")
        try Expect.equal(unknown.information_gaps.count, 1, "Unresolved place reported")
    }
}

enum SchedulingConflictTests {
    static func run() async throws {
        let result = try await Scheduling.Tools.Conflicts().call(
            .init(window_start: F.tuesday.start, window_end: F.tuesday.end),
            in: try F.context()
        )
        try Expect.equal(result.conflicts.map(\.kind), [.travel_infeasible, .overlap], "Travel then overlap, in time order")
        let travel = result.conflicts[0]
        try Expect.equal(travel.first.title, "Lunch", "From lunch at the office")
        try Expect.equal(travel.gap_minutes, 15, "Fifteen minutes between")
        try Expect.true((travel.required_minutes ?? 0) > 15, "Travel needs longer")
        try Expect.equal(result.conflicts[1].gap_minutes, -30, "Calls overlap by thirty minutes")
        try Expect.equal(result.events_considered, 5, "Tentative hold blocks and counts")

        let buffered = try await Scheduling.Tools.Conflicts().call(
            .init(window_start: F.tuesday.start, window_end: F.tuesday.end, buffer_minutes: 90),
            in: try F.context()
        )
        try Expect.contains(buffered.conflicts.map(\.kind), .insufficient_buffer, "Workshop to Call A is under ninety minutes")
    }
}

enum SchedulingCalendarTests {
    static func run() async throws {
        let ghost = SchedulingParticipant(identifier: "ghost", name: "Ghost", timeZone: F.zone, calendars: [CalendarPolicy("Ghost")])
        let result = try await Scheduling.Tools.ListCalendars().call(
            .init(),
            in: try F.context(F.runtime(extraParticipants: [ghost]))
        )
        let calendars = try requireFirst(result.sources).calendars
        try Expect.equal(calendars.first(where: { $0.title == "Levi" })?.participants, ["levi"], "Calendar mapped to its owner")
        try Expect.equal(result.participants.first?.identifier, "levi", "Primary participant first")
        try Expect.equal(result.information_gaps.count, 1, "Invisible calendar reported")
        try Expect.true(result.information_gaps[0].contains("Ghost"), "Gap names the calendar")
    }
}

private struct MissingElement: Error {}

private func requireFirst<Element>(_ elements: [Element]) throws -> Element {
    guard let first = elements.first else {
        throw MissingElement()
    }
    return first
}

enum SchedulingNowTests {
    static func run() throws {
        let wednesday = try Scheduling.Tools.Now.output(at: F.date("2026-11-18T15:00:00+01:00"), in: F.zone)
        try Expect.equal(wednesday.today, "2026-11-18", "Local date")
        try Expect.equal(wednesday.weekday, .wednesday, "Weekday")
        try Expect.equal(wednesday.coming_week_start, "2026-11-18T00:00:00+01:00", "Coming week from today")
        try Expect.equal(wednesday.coming_week_end, "2026-11-25T00:00:00+01:00", "Seven days on")
        try Expect.equal(wednesday.this_week_start, "2026-11-16T00:00:00+01:00", "This week from Monday")
        try Expect.equal(wednesday.this_week_end, "2026-11-23T00:00:00+01:00", "To the next Monday")

        let sunday = try Scheduling.Tools.Now.output(at: F.date("2026-11-22T23:30:00+01:00"), in: F.zone)
        try Expect.equal(sunday.this_week_start, "2026-11-16T00:00:00+01:00", "Sunday still belongs to Monday's week")

        let lateUTC = try Scheduling.Tools.Now.output(at: F.date("2026-11-22T23:30:00Z"), in: F.zone)
        try Expect.equal(lateUTC.today, "2026-11-23", "The zone decides the date")
        try Expect.equal(lateUTC.weekday, .monday, "Already Monday in Amsterdam")
    }
}
