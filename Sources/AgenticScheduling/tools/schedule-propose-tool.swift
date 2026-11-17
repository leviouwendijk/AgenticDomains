import Agentic
import Foundation
import Macros
import Schema

public extension Scheduling.Tools {
    /// The scheduling answer as the user sees it. The agent names its
    /// recommendation and alternatives; every time is evaluated again here,
    /// so what the user reads is what the tools computed.
    @Tool("schedule_propose")
    struct Propose {
        @JSONSchema
        public struct Option: HashableSource {
            /// Start, ISO 8601 with offset, taken from a search or evaluation.
            public let start: String
            /// What this option trades off, in a short phrase.
            public let note: String?

            public init(start: String, note: String? = nil) {
                self.start = start
                self.note = note
            }
        }

        @JSONSchema
        public struct Input: HashableSource {
            /// A short name for the appointment, such as `Intake with client`.
            public let title: String?
            /// The requirements the options were searched with.
            public let requirements: SlotRequirements
            public let recommendation: Option
            /// Up to three alternatives, best first.
            public let alternatives: [Option]?
            /// How the request was read, such as `"next Tuesday" = 24 Nov`.
            public let interpretation: String?
            /// Assumptions the user should check.
            public let assumptions: [String]?

            public init(
                title: String? = nil,
                requirements: SlotRequirements,
                recommendation: Option,
                alternatives: [Option]? = nil,
                interpretation: String? = nil,
                assumptions: [String]? = nil
            ) {
                self.title = title
                self.requirements = requirements
                self.recommendation = recommendation
                self.alternatives = alternatives
                self.interpretation = interpretation
                self.assumptions = assumptions
            }
        }

        @JSONSchema
        public struct ProposedOption: HashableResult {
            /// `A` for the recommendation, then `B`, `C`, `D`.
            public let label: String
            public let note: String?
            public let start: String
            public let end: String
            public let feasible: Bool
            public let placement: SlotPlacementKind
            public let violations: [SlotViolation]
            public let score: Double
            public let terms: [SlotScoreTerm]
            public let optional_available: [String]
            public let optional_unavailable: [String]
            public let travel: [TravelLeg]
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let title: String
            public let time_zone: String
            public let interpretation: String?
            public let participants: [String]
            public let optional_participants: [String]
            public let recommendation: ProposedOption
            public let alternatives: [ProposedOption]
            public let assumptions: [String]
            public let information_gaps: [String]
            /// The stretch of time shown around the options.
            public let view_start: String
            public let view_end: String
            /// Everyone's calendar over that stretch.
            public let calendars: [ParticipantBusy]
        }

        public static let purpose =
            "Present the scheduling answer to the user: the recommended time and up to three alternatives, each evaluated again against the requirements (feasibility, placement, score, travel), with everyone's calendar around them. Call it once you have chosen; the user sees the proposal, you read whether each option holds."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let runtime = try Scheduling.runtime(in: context)
            let requirements = try ResolvedRequirements(input.requirements, runtime: runtime)
            let options = [input.recommendation] + (input.alternatives ?? []).prefix(3)
            let slots = try options.enumerated().map { index, option in
                let start = try ScheduleTimestamp.parse(
                    option.start,
                    field: index == 0 ? "recommendation.start" : "alternatives[\(index - 1)].start"
                )
                return try ScheduleInterval(start: start, end: start.addingTimeInterval(requirements.duration.seconds))
            }

            let view = try Self.view(around: slots, zone: requirements.zone)
            let evaluator = try await SlotEvaluator.prepare(requirements, window: view, runtime: runtime)
            // Options speak in names, like the rest of the proposal.
            let names = Dictionary(
                (requirements.required + requirements.optional).map { ($0.identifier, $0.name) },
                uniquingKeysWith: { first, _ in first }
            )
            let named = { (identifiers: [String]) in identifiers.map { names[$0] ?? $0 } }
            var proposed: [ProposedOption] = []
            for (index, (option, slot)) in zip(options, slots).enumerated() {
                let assessment = await evaluator.assess(slot)
                let candidate = evaluator.candidate(slot, assessment: assessment, scored: await evaluator.score(slot))
                proposed.append(.init(
                    label: String(UnicodeScalar(UInt8(65 + index))),
                    note: option.note,
                    start: candidate.start,
                    end: candidate.end,
                    feasible: assessment.violations.isEmpty,
                    placement: assessment.placement,
                    violations: assessment.violations,
                    score: candidate.score,
                    terms: candidate.terms,
                    optional_available: named(candidate.optional_available),
                    optional_unavailable: named(candidate.optional_unavailable),
                    travel: assessment.travel
                ))
            }

            return .init(
                title: input.title ?? "Scheduling proposal",
                time_zone: requirements.zone.raw,
                interpretation: input.interpretation,
                participants: requirements.required.map(\.name),
                optional_participants: requirements.optional.map(\.name),
                recommendation: proposed[0],
                alternatives: Array(proposed.dropFirst()),
                assumptions: input.assumptions ?? [],
                information_gaps: await evaluator.oracle.gaps + FindSlots.visibilityGaps(requirements),
                view_start: ScheduleTimestamp.render(view.start, in: requirements.zone),
                view_end: ScheduleTimestamp.render(view.end, in: requirements.zone),
                calendars: (evaluator.required + evaluator.optional).map { Busy.busy($0, in: view) }
            )
        }

        /// Whole hours around the options, at least a working morning or
        /// afternoon wide, so neighbouring appointments show.
        static func view(around slots: [ScheduleInterval], zone: ScheduleTimeZone) throws -> ScheduleInterval {
            let calendar = zone.calendar
            let earliest = slots.map(\.start).min()!.addingTimeInterval(-3 * 3600)
            let latest = slots.map(\.end).max()!.addingTimeInterval(3 * 3600)
            let start = calendar.dateInterval(of: .hour, for: earliest)?.start ?? earliest
            var end = calendar.dateInterval(of: .hour, for: latest)?.end ?? latest
            if end.timeIntervalSince(start) < 8 * 3600 {
                end = start.addingTimeInterval(8 * 3600)
            }
            return try ScheduleInterval(start: start, end: end)
        }

        /// The model reads whether its choices hold, not the whole view.
        public func render(_ output: Output, input _: Input) -> String? {
            let lines = ([output.recommendation] + output.alternatives).map { option in
                var line = "\(option.label) \(option.start)–\(option.end): "
                line += option.feasible
                    ? "feasible, \(option.placement.rawValue), score \(String(format: "%.2f", option.score))"
                    : "NOT feasible (" + option.violations.map { $0.detail }.joined(separator: "; ") + ")"
                if !option.optional_unavailable.isEmpty {
                    line += "; optional unavailable: " + option.optional_unavailable.joined(separator: ", ")
                }
                return line
            }
            var text = "Proposal shown to the user:\n" + lines.joined(separator: "\n")
            if !output.information_gaps.isEmpty {
                text += "\nGaps: " + output.information_gaps.joined(separator: " ")
            }
            if !output.recommendation.feasible {
                text += "\nThe recommendation does not hold; search again or tell the user why."
            }
            return text
        }
    }
}
