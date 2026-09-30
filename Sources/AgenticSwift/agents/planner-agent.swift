import Agentic
import AgenticIO
import AgenticStandard
import Macros
import Schema

public extension SwiftLang.Agents {
    @Agent
    enum Planner {
        @JSONSchema
        public struct Input: HashableSource {
            public let objective: String
            public let constraints: [String]
            public let context: String?

            public init(
                objective: String,
                constraints: [String] = [],
                context: String? = nil
            ) {
                self.objective = objective
                self.constraints = constraints
                self.context = context
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let plan: [String]
            public let verification: [String]
            public let caveats: [String]

            public init(
                plan: [String],
                verification: [String],
                caveats: [String] = []
            ) {
                self.plan = plan
                self.verification = verification
                self.caveats = caveats
            }
        }

        public static let purpose = """
        Plan bounded Swift engineering work from an explicit objective, constraints, and available repository evidence.
        """

        public static let instructions = """
        Inspect relevant Swift structure and semantics before proposing work.
        Prefer the smallest coherent implementation sequence that preserves the existing architecture.
        Make verification explicit and surface unresolved uncertainty instead of inventing facts.
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

                    Standard.Tools.FindGuidelines.identifier,
                    Standard.Tools.GuidelineIndex.identifier,
                    Standard.Tools.ReadGuideline.identifier,
                    Standard.Tools.ReadGuidelineChapter.identifier
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
                    Explorer.definition.identifier,
                    Verifier.definition.identifier,
                ]
            )
        )

        public static let delegation = AgentDelegationPolicy.bounded(
            allowedAgents: .init(
                members: [
                    Explorer.definition.identifier,
                    Verifier.definition.identifier,
                ]
            ),
            limits: .init(
                depth: 1,
                children: 2,
                descendants: 2,
                concurrentChildren: 2
            )
        )
    }
}
