import Workspace

func agenticGitWorkspace(
    _ candidate: WorkspaceContext?,
    toolName: String
) async throws -> WorkspaceContext {
    let workspace = try AgenticGitToolSupport.requireWorkspace(
        candidate,
        toolName: toolName
    )

    try await AgenticGitToolSupport.requireRepositoryRoot(
        workspace,
        toolName: toolName
    )

    return workspace
}