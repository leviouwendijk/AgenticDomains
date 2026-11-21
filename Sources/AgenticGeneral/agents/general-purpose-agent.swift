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
    /// An unspecialized Agent: the core file and shell tools are visible up
    /// front, and the rest of the installed domains are discovered on demand.
    /// Applications fork it and add their own domains.
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
            )
                + .agents(Worker.self),
            visible: .tools(
                Standard.Tools.ClarifyWithUser.self,

                SystemIO.Tools.Search.self,
                SystemIO.Tools.Find.self,
                SystemIO.Tools.Read.self,
                SystemIO.Tools.Mutate.self,

                Shell.Tools.Run.self
            )
                + .agents(Worker.self)
        )

        /// Bounded assignments go to Workers, one level deep. Forks that bring
        /// their own Worker (Development) replace this policy.
        public static let delegation = AgentDelegationPolicy.bounded(
            allowedAgents: .init(
                members: [
                    Worker.self,
                ]
            ),
            limits: .init(
                depth: 1,
                children: 30,
                descendants: 30,
                concurrentChildren: 30
            )
        )
    }
}
