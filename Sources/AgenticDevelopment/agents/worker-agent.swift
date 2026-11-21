import Agentic
import AgenticAssertions
import AgenticGeneral
import AgenticHarness
import AgenticIO
import AgenticMath
import AgenticSessions
import AgenticStandard
import AgenticSwift
import AgenticTasks
import Macros
import Schema

public extension Development.Agents {
    @Agent
    enum Worker {
        public typealias Input = Tasks.Assignment
        public typealias Output = AgentTaskAttemptReport

        public static let purpose = """
        Implements one bounded, contracted assignment delegated by the \
        Development orchestrator and reports the attempt.
        """

        public static let instructions: AgentInstructions = [
            .text(
                """
                You are an implementation worker operating under the \
                Development orchestrator. Complete your assignment's contract. \
                Your assignment's fields:
                \(SchemaInstructionText.fields(of: Tasks.Assignment.self))
                """
            ),
            .instruction(Tasks.Instructions.Contract.definition),
            .instruction(Development.Instructions.NarrowScope.definition),
            .instruction(Development.Instructions.SourceInspection.definition),
            .text(
                """
                IMPLEMENTATION

                1. Identify the change and its acceptance conditions.
                2. Search narrowly for the relevant implementation.
                3. Read only the source needed to change it correctly.
                4. Identify directly affected call sites and dependencies.
                5. Make one coherent \(SystemIO.Tools.Mutate.identifier.rawValue) \
                pass covering the required changes, inside the write scope only.
                6. Report and stop.

                Prefer complete, coherent edits over partial fixes. Account for \
                directly affected usages when changing APIs or shared contracts. \
                Preserve naming conventions and architectural boundaries. No \
                unrelated refactoring, no speculative improvements, no further \
                implementation passes, no delegation.
                """
            ),
            .instruction(General.Instructions.EvidenceDiscipline.definition),
            .text(
                """
                REPORT

                Your output is the attempt report described above. When the \
                assignment names a task, record the same report with \
                \(Tasks.Tools.RecordAttempt.identifier.rawValue) before returning. \
                Recording submits the attempt; it does not complete the task.
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
                    SwiftLang.self,
                    Tasks.self,
                    Sessions.self,
                ]
            ),
            visible: .init(
                tools: .init(
                    members: [

                        SystemIO.Tools.Search.identifier,
                        SystemIO.Tools.Find.identifier,
                        SystemIO.Tools.Read.identifier,
                        SystemIO.Tools.Mutate.identifier,

                        SwiftLang.Tools.Parse.identifier,

                        Tasks.Tools.GetTask.identifier,
                        Tasks.Tools.RecordAttempt.identifier,
                    ]
                )
            )
        )

        // The model serving `.coder` is bound by the application.
        public static let modelSelection = AgentModelSelection(
            purpose: .coder
        )
    }
}
