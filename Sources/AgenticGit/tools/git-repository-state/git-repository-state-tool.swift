import Agentic
import AgenticExecution
import Workspace
import Interfaces
import Primitives
import Schema

public struct GitRepositoryStateTool: Tool {
    public typealias Input = AgenticGitEmptyToolInput
    public typealias Output = GitManagerRepositoryState
    public static let identifier: ToolIdentifier =
        "git_repository_state"

    public static let description =
        """
        Inspect read-only Git repository status and state for the current Agentic workspace, including branch, working-tree changes, and untracked files, without fetching or mutating the repository.
        """

    public static let risk: ActionRisk = .observe

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier {
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
