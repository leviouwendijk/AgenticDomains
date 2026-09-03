import Agentic
import AgenticExecution
import AgenticWorkspace
import Interfaces
import Primitives
import Schema

public struct GitRepositoryStateTool: TypedAgentTool {
    public typealias Input = AgenticGitEmptyToolInput
    public static let identifier: AgentToolIdentifier =
        "git_repository_state"

    public static let description =
        """
        Inspect read-only Git repository status and state for the current Agentic workspace, including branch, working-tree changes, and untracked files, without fetching or mutating the repository.
        """

    public static let risk: ActionRisk = .observe

    public init() {}

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        _ = input

        let workspace = try AgenticGitToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )

        let state = try await GitManagerRepositoryInspector.state(
            at: workspace.rootURL,
            fetch: false
        )

        return try JSONToolBridge.encode(
            state
        )
    }
}
