import Agentic
import AgenticIO
import AgenticStandard
import AgenticTasks
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
            /// The task being verified, when one exists; its acceptance applies.
            public let task: AgentTaskIdentifier?

            public init(
                objective: String,
                changedPaths: [String] = [],
                checks: [String] = [],
                task: AgentTaskIdentifier? = nil
            ) {
                self.objective = objective
                self.changedPaths = changedPaths
                self.checks = checks
                self.task = task
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

        public static let instructions: AgentInstructions = [
            .text(
                """
                Verify rather than infer success. Run the relevant available \
                checks (build, lint, parse, semantic inspection) and report their \
                concrete outcomes. Treat missing or inconclusive evidence as \
                unresolved rather than passed. Do not mutate source.

                When a task is named, read it with \
                \(Tasks.Tools.GetTask.identifier.rawValue) and verify each of its \
                acceptance conditions as a check.
                """
            ),
            .instruction(SwiftLang.Instructions.StructuralReading.definition),
        ]

        public static let capabilities = AgentCapabilities(
            available: .init(
                tools: .init(
                    domains: [
                        SwiftLang.definition.namespace,
                    ],
                    members: tools + SwiftAgentTools.guidelines
                ),
                programs: .init(
                    domains: [
                        SwiftLang.definition.namespace,
                    ]
                )
            ) + .init(
                namespaces: SwiftAgentTools.discoverableDomains
            ),
            visible: .init(
                tools: .init(
                    members: tools + [
                        SwiftLang.Tools.Build.identifier,
                        SwiftLang.Tools.LintFiles.identifier,
                        SwiftLang.Tools.LintPackage.identifier,
                    ]
                )
            )
        )

        private static let tools: [ToolIdentifier] =
            SwiftAgentTools.standard
            + SwiftAgentTools.read
            + SwiftAgentTools.swiftRead
            + SwiftAgentTools.repositoryRead
            + [
                Tasks.Tools.GetTask.identifier,
            ]

        // The model serving `.reviewer` is bound by the application.
        public static let modelSelection = AgentModelSelection(
            purpose: .reviewer
        )
    }
}
