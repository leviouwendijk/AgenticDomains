import Agentic

enum AgenticGitToolSupport {
    static func requireWorkspace(
        _ workspace: AgentWorkspace?,
        toolName: String
    ) throws -> AgentWorkspace {
        guard let workspace else {
            throw AgenticGitToolError.workspaceRequired(
                toolName
            )
        }

        return workspace
    }
}
