import Agentic
import AgenticIO
import AgenticStandard
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

            public init(
                objective: String,
                changedPaths: [String] = [],
                context: String? = nil
            ) {
                self.objective = objective
                self.changedPaths = changedPaths
                self.context = context
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

        public static let instructions = """
        Review the actual changed code and its surrounding contracts.
        Prioritize concrete correctness, architectural, API, concurrency, and verification findings.
        Do not mutate the workspace.
        Use delegated exploration or verification only when additional evidence is necessary.
        """

        public static let capabilities = AgentCapabilities(
            available: .init(
                tools: .init(
                domains: [
                    SwiftLang.definition.namespace,
                ],
                members: [
                    SystemIO.Tools.ReadFile.identifier,
                    SystemIO.Tools.ReadSelection.identifier,

                    SystemIO.Tools.ScanFilepaths.identifier,
                    SystemIO.Tools.SearchFilepaths.identifier,

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
