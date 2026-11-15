import Agentic
import AgenticAssertions
import AgenticGit
import AgenticIO
import AgenticStandard
import AgenticTasks
import Macros
import Schema

public extension SwiftLang.Agents {
    @Agent
    enum Reviewer {
        @JSONSchema
        public struct Input: HashableSource {
            public let objective: String
            public let changedPaths: [String]
            public let context: String?
            /// The task under review, when one exists; its contract applies.
            public let task: AgentTaskIdentifier?

            public init(
                objective: String,
                changedPaths: [String] = [],
                context: String? = nil,
                task: AgentTaskIdentifier? = nil
            ) {
                self.objective = objective
                self.changedPaths = changedPaths
                self.context = context
                self.task = task
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let findings: [String]
            public let risks: [String]
            public let recommendations: [String]

            public init(
                findings: [String],
                risks: [String] = [],
                recommendations: [String] = []
            ) {
                self.findings = findings
                self.risks = risks
                self.recommendations = recommendations
            }
        }

        public static let purpose = """
        Review Swift changes for correctness, architectural fit, regressions, and evidence gaps.
        """

        public static let instructions: AgentInstructions = [
            .text(
                """
                Review the actual changed code and its surrounding contracts. \
                Prioritize concrete correctness, architectural, API, concurrency, \
                and verification findings, each citing path:line. Do not mutate \
                the workspace. Use delegated exploration or verification only \
                when additional evidence is necessary.

                When a task is named, read it with \
                \(Tasks.Tools.GetTask.identifier.rawValue) and also check the \
                change against its contract. Inspect the actual changes with \
                \(Git.Tools.Diff.identifier.rawValue), and check verifiable \
                conditions deterministically with \
                \(Assertions.Tools.Evaluate.identifier.rawValue).
                """
            ),
            .instruction(Tasks.Instructions.Contract.definition),
            .instruction(SwiftLang.Instructions.StructuralReading.definition),
        ]

        public static let capabilities = AgentCapabilities(
            available: .init(
                tools: .init(
                    members: tools + SwiftAgentTools.guidelines + [
                        SwiftLang.Tools.LintFiles.identifier,
                        SwiftLang.Tools.LintSource.identifier,
                    ]
                ),
                programs: .init(
                    members: [
                        SwiftLang.Programs.MapChangeImpact.definition.identifier,
                    ]
                ),
                agents: delegates
            ) + .init(
                domains: SwiftAgentTools.discoverableDomains
            ),
            visible: .init(
                tools: .init(
                    members: tools
                ),
                agents: delegates
            )
        )

        public static let delegation = AgentDelegationPolicy.bounded(
            allowedAgents: delegates,
            limits: .init(
                depth: 1,
                children: 2,
                descendants: 2,
                concurrentChildren: 2
            )
        )

        private static let tools: [ToolIdentifier] =
            SwiftAgentTools.standard
            + SwiftAgentTools.read
            + SwiftAgentTools.swiftRead
            + SwiftAgentTools.repositoryRead
            + SwiftAgentTools.assertionChecks
            + [
                Tasks.Tools.GetTask.identifier,
            ]

        private static let delegates = AgentCapabilitySelection<AgentIdentifier>(
            members: [
                Explorer.definition.identifier,
                Verifier.definition.identifier,
            ]
        )

        // The model serving `.reviewer` is bound by the application.
        public static let modelSelection = AgentModelSelection(
            purpose: .reviewer
        )
    }
}
