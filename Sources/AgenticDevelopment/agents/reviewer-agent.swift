import Agentic
import AgenticAssertions
import AgenticGit
import AgenticIO
import AgenticStandard
import AgenticSwift
import AgenticTasks
import Macros
import Schema

public extension Development.Agents {
    @Agent
    enum Reviewer {
        /// Whether evidence shows an acceptance condition holds.
        @JSONSchema
        public enum Verdict: String, Sendable, Codable, Hashable, CaseIterable {
            /// Evidence shows the condition holds.
            case met
            /// Evidence shows the condition does not hold.
            case unmet
            /// No evidence either way; never treated as met.
            case unverified
        }

        /// What the coordinator should decide about the attempt.
        @JSONSchema
        public enum Recommendation: String, Sendable, Codable, Hashable, CaseIterable {
            /// Every condition met, no violated constraints, nothing out of scope.
            case accept
            /// Fixable within the contract; the note says what the next attempt must change.
            case reject
            /// Not achievable within the contract, e.g. a confirmed contract conflict; the note says why.
            case fail
        }

        @JSONSchema
        public struct ConditionReview: HashableResult {
            /// The acceptance condition, as the contract states it.
            public let condition: String
            /// Whether evidence shows it holds.
            public let verdict: Verdict
            /// What was checked: `path:line`, a diff hunk, or a tool result.
            public let evidence: String
        }

        @JSONSchema
        public struct Input: HashableSource {
            /// The task under review, when one exists.
            public let task: AgentTaskIdentifier?
            /// The contract the attempt is judged against.
            public let contract: AgentTaskContract
            /// The worker's account of the attempt; where to look, not proof.
            public let report: AgentTaskAttemptReport

            public init(
                task: AgentTaskIdentifier? = nil,
                contract: AgentTaskContract,
                report: AgentTaskAttemptReport
            ) {
                self.task = task
                self.contract = contract
                self.report = report
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            /// One review per acceptance condition, in contract order.
            public let conditions: [ConditionReview]
            /// Invariant constraints the change violates.
            public let violatedConstraints: [String]
            /// Changed paths outside the contract's write scope.
            public let outOfScopeChanges: [String]
            /// What the coordinator should decide.
            public let recommendation: Recommendation
            /// For reject, what the next attempt must change; for fail, why.
            public let note: String
        }

        public static let purpose = """
        Read-only acceptance review: checks an attempt against its task contract \
        using diff, source, parse, and lint evidence, and recommends accept, \
        reject, or fail. It never decides or changes the task itself.
        """

        public static let instructions: AgentInstructions = [
            .text(
                """
                You are an acceptance reviewer operating under the Development \
                orchestrator. Judge the attempt against its contract using \
                evidence, not the worker's report.
                """
            ),
            .instruction(Tasks.Instructions.Contract.definition),
            .instruction(Development.Instructions.EvidenceDiscipline.definition),
            .instruction(Development.Instructions.ReadOnly.definition),
            .text(
                """
                REVIEW

                1. Inspect the actual changes with \(Git.Tools.Diff.identifier.rawValue), \
                limited to the reported changed files and the contract's write scope.
                2. List every changed path outside the write scope.
                3. Give each acceptance condition one verdict, with evidence:
                \(SchemaInstructionText.values(of: Verdict.self))
                4. Check the invariant constraints against the diff; list any \
                violated.
                5. Check conditions that reduce to file or text facts (a file \
                exists, contains, or no longer contains something) \
                deterministically with \(Assertions.Tools.Evaluate.identifier.rawValue) \
                and cite its result as the evidence.
                6. Where useful, check syntax and style with the language's \
                parse and lint tools, e.g. \(SwiftLang.Tools.Parse.identifier.rawValue) \
                and \(SwiftLang.Tools.LintFiles.identifier.rawValue).

                Do not build, test, or run products.

                OUTPUT

                \(SchemaInstructionText.fields(of: Output.self))

                Recommendations:
                \(SchemaInstructionText.values(of: Recommendation.self))

                An \(Verdict.unverified.rawValue) condition is not \(Verdict.met.rawValue). When a condition can only be \
                verified by building or testing, say so in its evidence; the \
                orchestrator decides whether to run it.
                """
            ),
        ]

        // Read-only by construction: nothing that mutates is even available.
        public static let capabilities = AgentCapabilities(
            available: .init(
                tools: .init(
                    members: reviewTools
                )
            ),
            visible: .init(
                tools: .init(
                    members: reviewTools
                )
            )
        )

        private static let reviewTools: [ToolIdentifier] = [
            Standard.Tools.InspectCapability.identifier,

            SystemIO.Tools.SearchSources.identifier,
            SystemIO.Tools.SearchFilepaths.identifier,
            SystemIO.Tools.ReadSelection.identifier,
            SystemIO.Tools.ReadFile.identifier,

            Git.Tools.Diff.identifier,
            Git.Tools.RepositoryState.identifier,

            Assertions.Tools.Evaluate.identifier,
            Assertions.Tools.EvaluateSet.identifier,
            Assertions.Tools.InspectSet.identifier,

            SwiftLang.Tools.Parse.identifier,
            SwiftLang.Tools.LintFiles.identifier,
            SwiftLang.Tools.ReadSymbol.identifier,

            Tasks.Tools.GetTask.identifier,
        ]

        // The model serving `.reviewer` is bound by the application.
        public static let modelSelection = AgentModelSelection(
            purpose: .reviewer
        )
    }
}
