import Agentic
import AgenticIO
import AgenticStandard
import AgenticTasks
import Macros
import Schema

public extension SwiftLang.Agents {
    @Agent
    enum Implementer {
        public typealias Input = Tasks.Assignment
        public typealias Output = AgentTaskAttemptReport

        public static let purpose = """
        Implement bounded Swift changes while preserving architectural intent and verifying the resulting workspace.
        """

        public static let instructions: AgentInstructions = [
            .text(
                """
                Implement the assignment's contract. Its retryNote, when \
                present, says why a previous attempt was rejected; address it.
                Understand the relevant code and constraints before mutating. \
                Prefer coherent architectural changes over additive \
                compatibility layers.
                """
            ),
            .instruction(Tasks.Instructions.Contract.definition),
            .instruction(SwiftLang.Instructions.StructuralReading.definition),
            .instruction(SwiftLang.Instructions.TargetedEditing.definition),
            .text(
                """
                Verify with the strongest available compiler, lint, test, and \
                semantic evidence, and surface unresolved failures instead of \
                concealing them. Delegate symbol renames to \
                \(Renamer.definition.identifier.rawValue).

                Your output is the attempt report: summary, changedFiles, \
                mutationState (applied, pending_review, failed, or none, by \
                execution evidence), unresolved, and contractConflicts. When the \
                assignment names a task, record the same report with \
                \(Tasks.Tools.RecordAttempt.identifier.rawValue) before returning; \
                recording does not complete the task.
                """
            ),
        ]

        public static let capabilities = AgentCapabilities(
            available: .init(
                tools: .init(
                    domains: [
                        SwiftLang.definition.namespace,
                    ],
                    members: tools
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
                        Renamer.definition.identifier,
                    ]
                )
            ) + .init(
                namespaces: SwiftAgentTools.discoverableDomains
            ),
            visible: .init(
                tools: .init(
                    domains: [
                        SwiftLang.definition.namespace,
                    ],
                    members: tools
                ),
                agents: .init(
                    members: [
                        Renamer.definition.identifier,
                    ]
                )
            )
        )

        public static let delegation = AgentDelegationPolicy.bounded(
            allowedAgents: .init(
                members: [
                    Planner.definition.identifier,
                    Explorer.definition.identifier,
                    Reviewer.definition.identifier,
                    Verifier.definition.identifier,
                    Renamer.definition.identifier,
                ]
            ),
            limits: .init(
                depth: 2,
                children: 4,
                descendants: 6,
                concurrentChildren: 2
            )
        )

        private static let tools: [ToolIdentifier] =
            SwiftAgentTools.standard
            + SwiftAgentTools.read
            + [
                SystemIO.Tools.MutateFiles.identifier,

                Tasks.Tools.GetTask.identifier,
                Tasks.Tools.RecordAttempt.identifier,
            ]

        // The model serving `.coder` is bound by the application.
        public static let modelSelection = AgentModelSelection(
            purpose: .coder
        )
    }
}
