import Agentic
import Foundation
import Macros
import Schema

public extension Scheduling.Tools {
    @Tool("schedule_find_slots")
    struct FindSlots {
        @JSONSchema
        public struct Input: HashableSource {
            /// Earliest possible start, ISO 8601 with offset.
            public let window_start: String
            /// Latest possible end, ISO 8601 with offset.
            public let window_end: String
            public let requirements: SlotRequirements
            /// Granularity of candidate start times, at least 5. Defaults to
            /// the configured step.
            public let step_minutes: Int?
            /// Maximum candidates returned, 1...20. Default 5.
            public let limit: Int?

            public init(
                window_start: String,
                window_end: String,
                requirements: SlotRequirements,
                step_minutes: Int? = nil,
                limit: Int? = nil
            ) {
                self.window_start = window_start
                self.window_end = window_end
                self.requirements = requirements
                self.step_minutes = step_minutes
                self.limit = limit
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            /// Zone the candidate times are rendered in.
            public let time_zone: String
            /// Non-overlapping feasible slots, best first.
            public let candidates: [SlotCandidate]
            /// How many candidate start times each hard constraint excluded.
            public let rejected: [SlotRejection]
            /// Start times excluded only by reserved time: what allowing
            /// reserved time (escalation) would open.
            public let reserved_only_rejections: Int
            public let candidates_considered: Int
            public let information_gaps: [String]
        }

        public static let purpose =
            "Search a window for appointment slots that satisfy hard requirements (participants' commitments, reserved time unless escalated, offered slots when required, working hours, buffers, time of day, weekdays, travel to and from adjacent located events) and rank them by weighted preferences and offered-slot fit, with a score breakdown, each candidate's placement, and rejection counts."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let runtime = try Scheduling.runtime(in: context)
            let window = try ScheduleTimestamp.window(start: input.window_start, end: input.window_end)
            let requirements = try ResolvedRequirements(input.requirements, runtime: runtime)
            let step = try parsed("step_minutes") {
                try ScheduleMinutes.parse(input.step_minutes, default: runtime.defaults.step)
            }
            guard step.raw >= 5 else {
                throw Scheduling.InputFailure.invalid(field: "step_minutes", reason: "must be at least 5")
            }
            let limit = min(max(input.limit ?? 5, 1), 20)

            let evaluator = try await SlotEvaluator.prepare(requirements, window: window, runtime: runtime)
            let search = try await evaluator.search(step: step, limit: limit)

            var gaps = await evaluator.oracle.gaps
            if search.candidates.isEmpty, search.reservedOnly > 0 {
                gaps.append("\(search.reservedOnly) start times are blocked only by reserved time; allowing reserved time (escalation) would open them.")
            }
            if search.truncated {
                gaps.append("Search stopped after \(search.considered) start times; narrow the window or raise step_minutes to cover the rest.")
            }
            gaps += Self.visibilityGaps(requirements)

            return .init(
                time_zone: requirements.zone.raw,
                candidates: search.candidates,
                rejected: search.rejected,
                reserved_only_rejections: search.reservedOnly,
                candidates_considered: search.considered,
                information_gaps: gaps
            )
        }

        static func visibilityGaps(_ requirements: ResolvedRequirements) -> [String] {
            var gaps: [String] = []
            if requirements.location == nil {
                gaps.append("No location given; travel was not checked.")
            }
            return gaps
        }
    }

    @Tool("schedule_evaluate")
    struct Evaluate {
        @JSONSchema
        public struct Input: HashableSource {
            /// Proposed start, ISO 8601 with offset.
            public let start: String
            public let requirements: SlotRequirements

            public init(start: String, requirements: SlotRequirements) {
                self.start = start
                self.requirements = requirements
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let start: String
            public let end: String
            /// True when no hard requirement is violated.
            public let feasible: Bool
            public let placement: SlotPlacementKind
            /// Every violated hard requirement, not only the first.
            public let violations: [SlotViolation]
            public let score: Double
            public let terms: [SlotScoreTerm]
            public let optional_available: [String]
            public let optional_unavailable: [String]
            public let travel: [TravelLeg]
            public let information_gaps: [String]
        }

        public static let purpose =
            "Check one proposed appointment time against the same requirements as \(FindSlots.identifier.rawValue), reporting every violation, its placement, travel legs and the preference score. Use it for \"does this time work\" and \"why not that time\"."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let runtime = try Scheduling.runtime(in: context)
            let requirements = try ResolvedRequirements(input.requirements, runtime: runtime)
            let start = try ScheduleTimestamp.parse(input.start, field: "start")
            let slot = try ScheduleInterval(start: start, end: start.addingTimeInterval(requirements.duration.seconds))

            let evaluator = try await SlotEvaluator.prepare(requirements, window: slot, runtime: runtime)
            let assessment = await evaluator.assess(slot)
            let candidate = evaluator.candidate(slot, assessment: assessment, scored: evaluator.score(slot))

            return .init(
                start: candidate.start,
                end: candidate.end,
                feasible: assessment.violations.isEmpty,
                placement: assessment.placement,
                violations: assessment.violations,
                score: candidate.score,
                terms: candidate.terms,
                optional_available: candidate.optional_available,
                optional_unavailable: candidate.optional_unavailable,
                travel: assessment.travel,
                information_gaps: await evaluator.oracle.gaps + FindSlots.visibilityGaps(requirements)
            )
        }
    }
}
