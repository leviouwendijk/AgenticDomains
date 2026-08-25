import Foundation

public enum AgenticGitToolError:
    Error,
    Sendable,
    LocalizedError
{
    case workspaceRequired(String)

    public var errorDescription: String? {
        switch self {
        case .workspaceRequired(let toolName):
            return """
            \(toolName) requires an Agentic workspace.
            """
        }
    }
}
