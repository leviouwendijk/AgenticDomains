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
    /// An unspecialized Agent: little is visible up front, and the installed
    /// domains it may use are discovered on demand. Applications fork it and
    /// add their own domains.
    @Agent
    enum GeneralPurpose {
        public typealias Input = String
        public typealias Output = String

        public static let purpose = """
        General-purpose Agent that works toward the user's request with \
        whatever installed capabilities it needs, discovered on demand.
        """

        public static let instructions: AgentInstructions = General.Instructions.core

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
                Standard.Tools.ClarifyWithUser.self
            )
        )
    }
}
