import Agentic
import AgenticExecution
import AgenticWorkspace
import Interfaces
import Primitives
import Schema

public struct GitRepositoryStateTool: AgentTool {
    public typealias Input = AgenticGitEmptyToolInput
    public typealias Output = GitManagerRepositoryState
    public static let identifier: AgentToolIdentifier =
        "git_repository_state"

    public static let description =
        """
        Inspect read-only Git repository status and state for the current Agentic workspace, including branch, working-tree changes, and untracked files, without fetching or mutating the repository.
        """

    public static let risk: ActionRisk = .observe

    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init() {}

}
