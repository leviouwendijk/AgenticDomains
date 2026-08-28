import Foundation

public enum AgenticGitToolError:
    Error,
    Sendable,
    LocalizedError
{
    case workspaceRequired(String)
    case repositoryRootWorkspaceRequired(
        toolName: String,
        workspaceRoot: String,
        repositoryRoot: String
    )

    public var errorDescription: String? {
        switch self {
        case .workspaceRequired(let toolName):
            return """
            \(toolName) requires an Agentic workspace.
            """

        case .repositoryRootWorkspaceRequired(
            let toolName,
            let workspaceRoot,
            let repositoryRoot
        ):
            return """
            \(toolName) requires the selected Git working directory to equal the Git repository root.
            Working directory: \(workspaceRoot)
            Repository: \(repositoryRoot)
            """
        }
    }
}
