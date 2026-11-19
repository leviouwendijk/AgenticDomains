import Agentic
import AgenticGeneral
import AgenticGit
import AgenticIO
import AgenticStandard
import Schema

public extension Development.Agents {
    /// The general-purpose agent, specialized for development: source tools
    /// visible up front, a narrow edit workflow, and Workers to delegate
    /// bounded assignments to. Language tooling is left to forks.
    @Agent
    enum Developer: AgentFork {
        public typealias Base = General.Agents.GeneralPurpose

        public static let fork = AgentDerivation(
            purpose: """
            General-purpose development agent that works directly in the \
            workspace and can delegate bounded assignments to Workers.
            """,
            instructions: .appending([
                .instruction(Development.Instructions.NarrowScope.definition),
                .instruction(Development.Instructions.SourceInspection.definition),
                .instruction(Development.Instructions.Workflow.definition),
            ]),
            available: .agents(Worker.self),
            visible: .tools(
                SystemIO.Tools.SearchSources.self,
                SystemIO.Tools.SearchFilepaths.self,
                SystemIO.Tools.ScanFilepaths.self,
                SystemIO.Tools.ReadSelection.self,
                SystemIO.Tools.ReadFiles.self,
                SystemIO.Tools.MutateFiles.self,

                Git.Tools.RepositoryState.self
            )
                + .agents(Worker.self),
            delegation: .bounded(
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
        )
    }
}
