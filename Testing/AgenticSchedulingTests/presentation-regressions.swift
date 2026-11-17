import Agentic
import AgenticScheduling
import AgenticStandard
import Foundation
import Reporting
import Testing

private typealias F = SchedulingFixture

private struct PresentationFailure: Error {
    let what: String
    init(_ what: String) { self.what = what }
}

private func requireFirst<Element>(_ elements: [Element]) throws -> Element {
    guard let first = elements.first else { throw PresentationFailure("empty") }
    return first
}

enum SchedulingPresentationTests {
    static let requirements = SlotRequirements(duration_minutes: 60, participants: ["levi", "anna"], optional_participants: ["sam"])

    static func propose() async throws -> (Scheduling.Tools.Propose.Input, Scheduling.Tools.Propose.Output) {
        let input = Scheduling.Tools.Propose.Input(
            title: "Planning",
            requirements: requirements,
            recommendation: .init(start: "2026-11-23T14:00:00+01:00", note: "Sam can join"),
            alternatives: [
                .init(start: "2026-11-23T11:00:00+01:00", note: "Earlier; Sam is in review"),
                .init(start: "2026-11-23T09:30:00+01:00", note: "Before lunch"),
            ],
            interpretation: "\"Monday\" = 23 Nov",
            assumptions: ["Online, so no travel"]
        )
        return (input, try await Scheduling.Tools.Propose().call(input, in: try F.context()))
    }

    /// Every option is evaluated again; the model reads whether each holds.
    static func reevaluates() async throws {
        let (input, output) = try await propose()
        try Expect.equal(output.recommendation.label, "A", "Recommendation is A")
        try Expect.true(output.recommendation.feasible, "14:00 fits for Levi and Anna")
        try Expect.equal(output.alternatives.map(\.label), ["B", "C"], "Alternatives lettered")
        try Expect.true(output.alternatives[0].feasible, "11:00 fits")
        try Expect.equal(output.alternatives[0].optional_unavailable, ["Sam"], "Sam is in review at 11:00")
        try Expect.false(output.alternatives[1].feasible, "09:30 overlaps the standup")
        try Expect.contains(output.alternatives[1].violations.map(\.constraint), .busy, "Busy violation named")
        try Expect.equal(output.calendars.count, 3, "Required and optional calendars shown")
        let text = Scheduling.Tools.Propose().render(output, input: input) ?? ""
        try Expect.true(text.contains("C 2026-11-23T09:30:00+01:00") && text.contains("NOT feasible"), "Model reads the failing option")
    }

    /// The proposal is an attachment: facts, a timeline with the options
    /// marked, an options table and the checks.
    static func presentsProposal() async throws {
        let (input, output) = try await propose()
        guard let presentation = Scheduling.Tools.Propose().present(output, input: input) else {
            throw PresentationFailure("proposal presentation")
        }
        try Expect.equal(presentation.placement, .attachment, "The answer sits with the reply")
        let document = presentation.document
        try Expect.equal(document.title, "Planning", "Titled by the agent")
        guard case .facts(let facts) = document.blocks.first else {
            throw PresentationFailure("facts lead")
        }
        try Expect.equal(facts.facts.first?.value, "Mon 23 Nov 14:00–15:00", "Recommendation in the user's zone")
        let timelines = document.blocks.compactMap { block -> ReportBlock.Timeline? in
            if case .timeline(let timeline) = block { return timeline }
            return nil
        }
        let timeline = try requireFirst(timelines)
        try Expect.equal(timeline.lanes.map(\.label), ["Levi", "Anna", "Sam (optional)", "Options"], "A lane per person, then the options")
        try Expect.equal(timeline.lanes[3].spans.map(\.label), ["A · recommended", "B", "C · does not fit"], "Options marked and checked")
        try Expect.true(timeline.lanes[0].spans.contains { $0.mark == .occupied && $0.label == "Standup" }, "Commitments by name")
        let options = try requireFirst(document.datasets.filter { $0.id == "options" })
        try Expect.equal(options.rows.count, 3, "Every option in the table")
        try Expect.equal(options.coverage, .complete, "Tool-computed rows are complete")
        try Expect.true(document.blocks.contains {
            if case .callout(let callout) = $0 { return callout.tone == .info }
            return false
        }, "Gaps and assumptions to check")
    }

    /// Working results stay with their call.
    static func intermediateResultsAreInspectorOnly() async throws {
        let context = try F.context()
        let busyInput = Scheduling.Tools.Busy.Input(window_start: F.monday.start, window_end: F.monday.end, participants: ["levi", "anna"])
        let busy = try await Scheduling.Tools.Busy().call(busyInput, in: context)
        let busyView = try requireSome(Scheduling.Tools.Busy().present(busy, input: busyInput))
        try Expect.equal(busyView.placement, .inspector, "Busy view in the inspector")
        try Expect.true(busyView.document.blocks.contains { if case .timeline = $0 { return true }; return false }, "Busy time as a timeline")

        let slotsInput = Scheduling.Tools.FindSlots.Input(window_start: F.monday.start, window_end: F.monday.end, requirements: requirements)
        let slots = try await Scheduling.Tools.FindSlots().call(slotsInput, in: context)
        let slotsView = try requireSome(Scheduling.Tools.FindSlots().present(slots, input: slotsInput))
        try Expect.equal(slotsView.placement, .inspector, "Slot search in the inspector")
        try Expect.equal(slotsView.document.datasets.first?.rows.count, slots.candidates.count, "Every candidate listed")

        let agendaInput = Scheduling.Tools.Agenda.Input(window_start: F.monday.start, window_end: F.monday.end)
        let agenda = try await Scheduling.Tools.Agenda().call(agendaInput, in: context)
        let agendaView = try requireSome(Scheduling.Tools.Agenda().present(agenda, input: agendaInput))
        try Expect.equal(agendaView.placement, .inspector, "Agenda in the inspector")
        guard case .timeline(let agendaTimeline)? = agendaView.document.blocks.first else {
            throw PresentationFailure("agenda timeline")
        }
        try Expect.true(agendaTimeline.lanes.flatMap(\.spans).contains { $0.label == "Standup" && $0.mark == .occupied }, "Blocking entries drawn")
        try Expect.false(agendaTimeline.lanes.flatMap(\.spans).contains { $0.label == "Holiday" }, "All-day entries not drawn")

        let conflictsInput = Scheduling.Tools.Conflicts.Input(window_start: F.tuesday.start, window_end: F.tuesday.end)
        let conflicts = try await Scheduling.Tools.Conflicts().call(conflictsInput, in: context)
        let conflictsView = try requireSome(Scheduling.Tools.Conflicts().present(conflicts, input: conflictsInput))
        try Expect.equal(conflictsView.document.datasets.first?.rows.count, conflicts.conflicts.count, "Every conflict listed")
    }

    /// The Scheduler can present overviews as reports.
    static func schedulerPresents() throws {
        let tools = Scheduling.Agents.Scheduler.capabilities.visible.tools.members
        try Expect.contains(tools, Scheduling.Tools.Propose.identifier, "Proposal visible")
        try Expect.contains(tools, Standard.Tools.CreateReport.identifier, "Reports visible")
        try Expect.contains(
            Scheduling.Agents.Scheduler.capabilities.available.tools.members,
            Standard.Tools.CreateReport.identifier,
            "Reports available"
        )
    }

    private static func requireSome<T>(_ value: T?) throws -> T {
        guard let value else { throw PresentationFailure("missing value") }
        return value
    }
}
