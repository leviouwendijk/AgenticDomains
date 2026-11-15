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
        @JSONSchema
        public enum Verdict: String, Sendable, Codable, Hashable, CaseIterable {
            case met
            case unmet
            /// No evidence either way; never treated as met.
            case unverified
        }

        @JSONSchema
        public enum Recommendation: String, Sendable, Codable, Hashable, CaseIterable {
            case accept
            case reject
            case fail
        }

        @JSONSchema
        public struct ConditionReview: HashableResult {
            public let condition: String
            public let verdict: Verdict
            /// What was checked: `path:line`, a diff hunk, or a tool result.
            public let evidence: String
        }

        @JSONSchema
        public struct Input: HashableSource {
            public let task: AgentTaskIdentifier?
            public let contract: AgentTaskContract
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
            /// Changed paths outside the contract's writeScope.
            public let outOfScopeChanges: [String]
            public let recommendation: Recommendation
            /// For reject: what the next attempt must fix, used as its retryNote.
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
                limited to the reported changedFiles and the contract's writeScope.
                2. List every changed path outside writeScope in outOfScopeChanges.
                3. Give each acceptance condition one verdict, with evidence: \
                met when you saw it hold, unmet when you saw it fail, unverified \
                when you could not establish either.
                4. Check user_instruction and accepted_decision constraints \
                against the diff; list any violated.
                5. Check conditions that reduce to file or text facts (a file \
                exists, contains, or no longer contains something) \
                deterministically with \(Assertions.Tools.Evaluate.identifier.rawValue) \
                and cite its result as the evidence.
                6. Where useful, check syntax and style with the language's \
                parse and lint tools, e.g. \(SwiftLang.Tools.Parse.identifier.rawValue) \
                and \(SwiftLang.Tools.LintFiles.identifier.rawValue).

                Do not build, test, or run products.

                RECOMMENDATION

                accept: every condition met, no violated constraints, nothing \
                out of scope.
                reject: fixable within the contract; note says exactly what \
                the next attempt must change.
                fail: not achievable within the contract, for example a \
                confirmed contract conflict; note says why.

                An unverified condition is not met. When a condition can only be \
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
