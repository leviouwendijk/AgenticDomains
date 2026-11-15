import Agentic
import AgenticIO
import AgenticStandard
import AgenticTasks
import Macros
import Schema

public extension SwiftLang.Agents {
    @Agent
    enum Explorer {
        @JSONSchema
        public struct Input: HashableSource {
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
        public struct Output: HashableResult {
            /// Each finding cites `path:line` evidence.
            public let findings: [String]
            public let relevantPaths: [String]
            public let uncertainties: [String]
            /// What was searched and what was deliberately not.
            public let coverage: [String]

            public init(
                findings: [String],
                relevantPaths: [String] = [],
                uncertainties: [String] = [],
                coverage: [String] = []
            ) {
                self.findings = findings
                self.relevantPaths = relevantPaths
                self.uncertainties = uncertainties
                self.coverage = coverage
            }
        }

        public static let purpose = """
        Explore Swift code, package structure, semantics, and surrounding evidence without performing implementation work.
        """

        public static let instructions: AgentInstructions = [
            .text(
                """
                Inspect before concluding. Trace relevant symbols, package \
                relationships, semantic structure, and existing conventions. \
                Never mutate the workspace; you have no tools that could.
                """
            ),
            .instruction(SwiftLang.Instructions.StructuralReading.definition),
            .text(
                """
                For what depends on a symbol, run \
                \(SwiftLang.Programs.MapChangeImpact.definition.identifier.rawValue) \
                first, then text-search the names its coverage lists to catch \
                string, reflective, and cross-package references.

                Cite every finding as path:line. Distinguish verified facts from \
                inference, list what remains uncertain, and state your coverage: \
                what you searched and what you did not.
                """
            ),
        ]

        // Read-only by construction: nothing that mutates is available.
        public static let capabilities = AgentCapabilities(
            available: .init(
                tools: .init(
                    members: tools + SwiftAgentTools.guidelines
                ),
                programs: .init(
                    members: [
                        SwiftLang.Programs.MapChangeImpact.definition.identifier,
                    ]
                )
            ) + .init(
                domains: SwiftAgentTools.discoverableDomains
            ),
            visible: .init(
                tools: .init(
                    members: tools
                ),
                programs: .init(
                    members: [
                        SwiftLang.Programs.MapChangeImpact.definition.identifier,
                    ]
                )
            )
        )

        private static let tools: [ToolIdentifier] =
            SwiftAgentTools.standard
            + SwiftAgentTools.read
            + SwiftAgentTools.swiftRead
            + [
                Tasks.Tools.GetTask.identifier,
            ]

        // The model serving `.researcher` is bound by the application.
        public static let modelSelection = AgentModelSelection(
            purpose: .researcher
        )
    }
}
