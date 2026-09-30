import Agentic
import AgenticIO
import AgenticStandard
import Macros
import Schema

public extension SwiftLang.Agents {
    @Agent
    enum Implementer {
        @JSONSchema
        public struct Input: HashableSource {
            public let objective: String
            public let plan: [String]
            public let constraints: [String]

            public init(
                objective: String,
                plan: [String] = [],
                constraints: [String] = []
            ) {
                self.objective = objective
                self.plan = plan
                self.constraints = constraints
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let summary: String
            public let changedPaths: [String]
            public let verification: [String]
            public let unresolved: [String]

            public init(
                summary: String,
                changedPaths: [String] = [],
                verification: [String] = [],
                unresolved: [String] = []
            ) {
                self.summary = summary
                self.changedPaths = changedPaths
                self.verification = verification
                self.unresolved = unresolved
            }
        }

        public static let purpose = """
        Implement bounded Swift changes while preserving architectural intent and verifying the resulting workspace.
        """

        public static let instructions = """
        Understand the relevant code and constraints before mutating.
        Prefer coherent architectural changes over additive compatibility layers.
        Verify changes with the strongest available compiler, lint, test, and semantic evidence.
        Surface unresolved failures instead of concealing them.
        """

        public static let capabilities = AgentCapabilities(
            tools: .init(
                domains: [
                    SwiftLang.definition.namespace,
                ],
                members: [
                    SystemIO.Tools.ReadFile.identifier,
                    SystemIO.Tools.ReadSelection.identifier,

                    SystemIO.Tools.ScanPaths.identifier,
                    SystemIO.Tools.FindPaths.identifier,

                    SystemIO.Tools.SearchSources.identifier,
                    SystemIO.Tools.LoadSearchContext.identifier,
                    SystemIO.Tools.ProveSearchResults.identifier,

                    SystemIO.Tools.MutateFiles.identifier,

                    // maybe clutters the context window redundantly?

                    // Standard.Tools.FindGuidelines.identifier,
                    // Standard.Tools.GuidelineIndex.identifier,
                    // Standard.Tools.ReadGuideline.identifier,
                    // Standard.Tools.ReadGuidelineChapter.identifier
                ]
            ),
            programs: .init(
                domains: [
                    SwiftLang.definition.namespace,
                ]
            ),
            inferences: .init(
                domains: [
                    SwiftLang.definition.namespace,
                ]
            ),
            agents: .init(
                members: [
                    Planner.definition.identifier,
                    Explorer.definition.identifier,
                    Reviewer.definition.identifier,
                    Verifier.definition.identifier,
                ]
            )
        )

        public static let delegation = AgentDelegationPolicy.bounded(
            allowedAgents: .init(
                members: [
                    Planner.definition.identifier,
                    Explorer.definition.identifier,
                    Reviewer.definition.identifier,
                    Verifier.definition.identifier,
                ]
            ),
            limits: .init(
                depth: 2,
                children: 4,
                descendants: 6,
                concurrentChildren: 2
            )
        )
    }
}
