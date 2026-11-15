import Agentic
import AgenticAssertions
import AgenticGit
import AgenticHarness
import AgenticIO
import AgenticMath
import AgenticStandard
import AgenticSwift
import AgenticTasks
import Macros
import Schema

public extension Development.Agents {
    @Agent
    enum Orchestrator {
        public typealias Input = String
        public typealias Output = String

        public static let purpose = """
        Development orchestrator: decomposes the user's objective into \
        contracted tasks, delegates scouting, implementation, and review, \
        and reports what was actually done.
        """

        public static let instructions: AgentInstructions = [
            .text(
                """
                You are the development orchestrator for the active workspace. \
                Understand the user's objective, determine the necessary work, \
                delegate it, judge the results, and report.

                Do not mutate source yourself; delegate implementation to \
                \(Worker.definition.identifier.rawValue).
                """
            ),
            .instruction(Development.Instructions.NarrowScope.definition),
            .instruction(Development.Instructions.SourceInspection.definition),
            .text(
                """
                Inspect only enough to establish task boundaries. Workers inspect \
                their own implementation details.

                SCOUTING

                When answering a question would take more than a few searches or \
                reads (what depends on a symbol, every affected site, an \
                unfamiliar area), delegate it to \(Scout.definition.identifier.rawValue). \
                Ask specific questions, give a scope, and pass the facts you \
                already hold. Independent questions may go to concurrent scouts. \
                Read a scout's coverage before treating its sites as complete.

                Scout findings feed contracts directly: \
                \(Scout.Confidence.verified.rawValue) findings become \
                \(AgentTaskConstraintProvenance.observed.rawValue) constraints, \
                \(Scout.Confidence.likely.rawValue) or \
                \(Scout.Confidence.unverified.rawValue) ones become \
                \(AgentTaskConstraintProvenance.hypothesis.rawValue) constraints, \
                and the scout's candidate sites carry into the contract.
                """
            ),
            .instruction(Tasks.Instructions.Contract.definition),
            .text(
                """
                DELEGATION

                Each worker assignment carries a contract. Record user statements \
                as \(AgentTaskConstraintProvenance.user_instruction.rawValue), \
                interfaces you settled as \
                \(AgentTaskConstraintProvenance.accepted_decision.rawValue), \
                inspected facts as \(AgentTaskConstraintProvenance.observed.rawValue), \
                and unverified assumptions as \
                \(AgentTaskConstraintProvenance.hypothesis.rawValue). Settle a \
                shared interface or invariant before assigning dependent \
                implementations, and include it in each.

                A single coherent change goes to one worker. Prefer independent \
                tasks that can run concurrently; avoid overlapping write scopes \
                between concurrent workers.

                TASKS

                For work with several assignments, or dependencies between them:
                    - Create one task per assignment with \
                \(Tasks.Tools.CreateTask.identifier.rawValue), carrying its \
                contract and the tasks it is blocked by. Pass the task id in \
                the worker's assignment.
                    - Delegate only ready tasks: \
                \(AgentTaskStatus.pending.rawValue) and unblocked.
                    - The worker records its report on the task. Judge it against \
                the acceptance conditions and the actual mutation evidence. For \
                changes spanning several files or carrying invariant constraints, \
                delegate that judgment to \(Reviewer.definition.identifier.rawValue) \
                and follow its recommendation unless you hold contrary evidence.
                    - Decide with \(Tasks.Tools.AcceptTask.identifier.rawValue), \
                \(Tasks.Tools.RejectTask.identifier.rawValue) (reassigning with the \
                reason as the retry note), or \(Tasks.Tools.FailTask.identifier.rawValue). \
                Accepting a task unblocks its dependents.
                    - When a report lists contract conflicts, revise the contract, \
                or the decision behind it, before reassigning. Never reassign an \
                unchanged contract.

                Never implement yourself after delegation fails; report the \
                failure or justify one bounded retry.
                """
            ),
            .instruction(Development.Instructions.EvidenceDiscipline.definition),
            .text(
                """
                WORKFLOW

                1. Identify the requested outcome and its boundaries.
                2. Inspect enough to define assignments; send broader questions \
                to scouts.
                3. Partition into tasks where warranted.
                4. Delegate implementation.
                5. Review results, through the reviewer where warranted.
                6. Identify incomplete work, blockers, and approval requirements.
                7. Report and stop. Do not start further passes unasked.

                Ask with \(Standard.Tools.ClarifyWithUser.identifier.rawValue) \
                only when the objective cannot reasonably be completed from the \
                available context.

                REPORT

                Summarize what was delegated, what each agent accomplished, which \
                changes were actually applied, and any outstanding approvals, \
                failures, or blockers. Keep it concise unless asked for detail. \
                Never claim completion when delegated execution failed.
                """
            ),
        ]

        public static let capabilities = AgentCapabilities(
            available: .init(
                domains: [
                    Standard.self,
                    Harness.self,
                    Math.self,
                    Assertions.self,
                    SystemIO.self,
                    Git.self,
                    SwiftLang.self,
                    Tasks.self,
                ],
                agents: delegates
            ),
            visible: .init(
                tools: .init(
                    members: [
                        Standard.Tools.FindCapabilities.identifier,
                        Standard.Tools.ClarifyWithUser.identifier,
                        Standard.Tools.InspectCapability.identifier,

                        Standard.Tools.CreateGraph.identifier,
                        Standard.Tools.CreateReport.identifier,
                        Standard.Tools.CreateCallTree.identifier,

                        SystemIO.Tools.SearchSources.identifier,
                        SystemIO.Tools.SearchFilepaths.identifier,
                        SystemIO.Tools.ScanFilepaths.identifier,
                        SystemIO.Tools.ReadSelection.identifier,
                        SystemIO.Tools.ReadFile.identifier,

                        Git.Tools.RepositoryState.identifier,
                        Git.Tools.Diff.identifier,

                        SwiftLang.Tools.Parse.identifier,

                        Tasks.Tools.CreateTask.identifier,
                        Tasks.Tools.ListTasks.identifier,
                        Tasks.Tools.GetTask.identifier,
                        Tasks.Tools.UpdateTask.identifier,
                        Tasks.Tools.AcceptTask.identifier,
                        Tasks.Tools.RejectTask.identifier,
                        Tasks.Tools.FailTask.identifier,
                    ]
                ),
                agents: delegates
            )
        )

        public static let delegation = AgentDelegationPolicy.bounded(
            allowedAgents: delegates,
            limits: .init(
                depth: 1,
                children: 30,
                descendants: 30,
                concurrentChildren: 30
            )
        )

        private static let delegates = AgentCapabilitySelection<AgentIdentifier>(
            members: [
                Worker.definition.identifier,
                Scout.definition.identifier,
                Reviewer.definition.identifier,
            ]
        )

        // The model serving `.planner` is bound by the application.
        public static let modelSelection = AgentModelSelection(
            purpose: .planner
        )
    }
}
