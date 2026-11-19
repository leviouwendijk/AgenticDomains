import Agentic
import AgenticAssertions
import AgenticGit
import AgenticHarness
import AgenticIO
import AgenticMath
import AgenticProcesses
import AgenticSessions
import AgenticStandard
import AgenticTasks
import Schema

public extension General.Agents {
    /// The general-purpose agent's delegate: one bounded assignment, any kind
    /// of work, reported as an attempt. Specialized workers (Development's)
    /// add their own workflow; this one adds none.
    @Agent
    enum Worker {
        public typealias Input = Tasks.Assignment
        public typealias Output = AgentTaskAttemptReport

        public static let purpose = """
        Completes one bounded, contracted assignment delegated by a \
        general-purpose agent and reports the attempt.
        """

        public static let instructions: AgentInstructions = [
            .text(
                """
                You are a worker operating under a general-purpose agent. \
                Complete your assignment's contract. Your assignment's fields:
                \(SchemaInstructionText.fields(of: Tasks.Assignment.self))
                """
            ),
            .instruction(Tasks.Instructions.Contract.definition),
            .instruction(General.Instructions.ContextFirst.definition),
            .instruction(General.Instructions.CapabilityDiscovery.definition),
            .text(
                """
                SCOPE

                Do what the assignment asks and nothing beside it. You cannot \
                ask the user; when the assignment leaves a decision open, take \
                the narrowest reading and say so in the report. No delegation.
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
            available: .domains(
                Standard.self,
                Harness.self,
                Math.self,
                Assertions.self,
                Tasks.self,
                SystemIO.self,
                Git.self,
                Shell.self,
                Sessions.self
            ),
            visible: .tools(
                Tasks.Tools.GetTask.self,
                Tasks.Tools.RecordAttempt.self
            )
        )
    }
}
