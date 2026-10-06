import Agentic
import AgenticIO
import AgenticStandard
import Macros
import Schema

public extension SwiftLang.Agents {
    @Agent
    enum Verifier {
        @JSONSchema
        public struct Input: HashableSource {
            public let objective: String
            public let changedPaths: [String]
            public let checks: [String]

            public init(
                objective: String,
                changedPaths: [String] = [],
                checks: [String] = []
            ) {
                self.objective = objective
                self.changedPaths = changedPaths
                self.checks = checks
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let passed: [String]
            public let failed: [String]
            public let evidence: [String]

            public init(
                passed: [String] = [],
                failed: [String] = [],
                evidence: [String] = []
            ) {
                self.passed = passed
                self.failed = failed
                self.evidence = evidence
            }
        }

        public static let purpose = """
        Verify bounded Swift engineering work using compiler, lint, test, semantic, and repository evidence.
        """

        public static let instructions = """
        Verify rather than infer success.
        Run the relevant available checks and report their concrete outcomes.
        Treat missing or inconclusive evidence as unresolved rather than passed.
        Do not mutate the workspace.
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
            )
        )
        )
    }
}
