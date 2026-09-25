import Agentic
import AgenticIO
import Macros
import Schema

public extension SwiftLang.Agents {
    @Agent
    enum Explorer {
        @JSONSchema
        public struct Input: HashableProduct {
            public let objective: String
            public let paths: [String]
            public let questions: [String]

            public init(
                objective: String,
                paths: [String] = [],
                questions: [String] = []
            ) {
                self.objective = objective
                self.paths = paths
                self.questions = questions
            }
        }

        @JSONSchema
        public struct Output: HashableProduct {
            public let findings: [String]
            public let relevantPaths: [String]
            public let uncertainties: [String]

            public init(
                findings: [String],
                relevantPaths: [String] = [],
                uncertainties: [String] = []
            ) {
                self.findings = findings
                self.relevantPaths = relevantPaths
                self.uncertainties = uncertainties
            }
        }

        public static let purpose =
            "Explore Swift code, package structure, semantics, and surrounding evidence without performing implementation work."

        public static let instructions = """
        Inspect before concluding.
        Trace relevant symbols, package relationships, semantic structure, and existing conventions.
        Return concrete findings and explicitly distinguish verified facts from unresolved uncertainty.
        Do not mutate the workspace.
        """

        public static let capabilities = AgentCapabilities(
            tools: .init(
                domains: [
                    SwiftLang.definition.namespace,
                ],
                members: [
                    SystemIO.Tools.ReadFile.identifier,
                    SystemIO.Tools.ScanPaths.identifier
                ]
            ),
            inferences: .init(
                domains: [
                    SwiftLang.definition.namespace,
                ]
            )
        )
    }
}
