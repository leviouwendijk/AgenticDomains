import Foundation

public enum AgenticProcessesToolError:
    Error,
    Sendable,
    LocalizedError
{
    case workspaceRequired(String)
    case emptyCommand(String)
    case timeoutExceedsMaximum(
        toolName: String,
        requested: Int,
        maximum: Int
    )

    public var errorDescription: String? {
        switch self {
        case .workspaceRequired(let toolName):
            return """
            \(toolName) requires an Agentic workspace.
            """

        case .emptyCommand(let toolName):
            return """
            \(toolName) requires a non-empty command.
            """

        case .timeoutExceedsMaximum(
            let toolName,
            let requested,
            let maximum
        ):
            return """
            \(toolName) requested a timeout of \(requested)s, which exceeds the host maximum of \(maximum)s.
            """
        }
    }
}
