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

public extension Development.Agents {
    /// An unspecialized Agent: little is visible up front, and the installed
    /// domains it may use are discovered on demand.
    @Agent
    enum GeneralPurpose {
        public typealias Input = String
        public typealias Output = String

        public static let purpose = """
        General-purpose Agent that follows the user's request using workspace, \
        repository, shell, session, and task capabilities discovered on demand.
        """

        public static let instructions: AgentInstructions = [
            .text(
                """
                Follow the user's request.

                Few tools are visible at first. Use \
                \(Standard.Tools.FindCapabilities.identifier.rawValue) to find an \
                installed capability you need, and \
                \(Standard.Tools.InspectCapability.identifier.rawValue) to read its \
                contract before using it.

                Ask with \(Standard.Tools.ClarifyWithUser.identifier.rawValue) only \
                when the request cannot reasonably be completed from the available \
                context.
                """
            ),
            .instruction(Development.Instructions.EvidenceDiscipline.definition),
        ]

        public static let capabilities = AgentCapabilities(
            available: .init(
                domains: [
                    Standard.self,
                    Harness.self,
                    Math.self,
                    Assertions.self,
                    Tasks.self,
                    SystemIO.self,
                    Git.self,
                    Shell.self,
                    Sessions.self,
                ]
            ),
            visible: .init(
                tools: .init(
                    members: [
                        Standard.Tools.ClarifyWithUser.identifier,
                        Standard.Tools.FindCapabilities.identifier,
                        Standard.Tools.InspectCapability.identifier,
                    ]
                )
            )
        )
    }
}
