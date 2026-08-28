import Agentic
import AgenticExecution
import AgenticWorkspace
import Interfaces
import Primitives

public struct GitRepositoryStateTool: StaticAgentTool {
    public static let identifier: AgentToolIdentifier =
        "git_repository_state"

    public static let description =
        """
        Inspect Git repository state for the current Agentic workspace without fetching or mutating the repository.
        """

    public static let risk: ActionRisk = .observe

    public static var inputSchema: JSONValue? {
        JSONSchema.object {}
    }

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
