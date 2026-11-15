import Agentic
import AgenticIO
import AgenticStandard
import AgenticTasks
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
            /// Tasks recorded for the plan, when it warranted them.
            public let tasks: [AgentTaskIdentifier]

            public init(
                plan: [String],
                verification: [String],
                caveats: [String] = [],
                tasks: [AgentTaskIdentifier] = []
            ) {
                self.plan = plan
                self.verification = verification
                self.caveats = caveats
                self.tasks = tasks
            }
        }

        public static let purpose = """
        Plan bounded Swift engineering work from an explicit objective, constraints, and available repository evidence.
        """

        public static let instructions: AgentInstructions = [
            .text(
                """
                Inspect relevant Swift structure and semantics before proposing \
                work. Prefer the smallest coherent implementation sequence that \
                preserves the existing architecture. Make verification explicit \
                and surface unresolved uncertainty instead of inventing facts.
                Delegate broad discovery to \(Explorer.definition.identifier.rawValue).
                """
            ),
            .instruction(SwiftLang.Instructions.StructuralReading.definition),
            .instruction(Tasks.Instructions.Contract.definition),
            .text(
                """
                When the plan has several steps with dependencies between them, \
                record each step as a task with \
                \(Tasks.Tools.CreateTask.identifier.rawValue): a contract per step \
                and blockedBy for its prerequisites. Return their identifiers in \
                tasks. A single coherent change needs no tasks.
                """
            ),
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
                ),
                inferences: .init(
                    domains: [
                        SwiftLang.definition.namespace,
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
                programs: .init(
                    members: [
                        SwiftLang.Programs.MapChangeImpact.definition.identifier,
                    ]
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
            + [
                Tasks.Tools.CreateTask.identifier,
                Tasks.Tools.ListTasks.identifier,
                Tasks.Tools.GetTask.identifier,
            ]

        private static let delegates = AgentCapabilitySelection<AgentIdentifier>(
            members: [
                Explorer.definition.identifier,
                Verifier.definition.identifier,
            ]
        )

        // The model serving `.planner` is bound by the application.
        public static let modelSelection = AgentModelSelection(
            purpose: .planner
        )
    }
}
