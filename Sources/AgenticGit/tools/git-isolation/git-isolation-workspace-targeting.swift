import AgenticExecution
import AgenticWorkspace

func agenticGitScopedWorkspace(
    _ context: AgentToolExecutionContext,
    toolName: String
) async throws -> AgentWorkspace {
    let execution = try await GitWorkspaceExecution.resolve(
        context,
        toolName: toolName
    )

    return try AgentWorkspace(
        root: execution.repositoryRoot
    )
}

extension GitWorktreeListTool {
    public var execution: AgentToolExecutionContract { .targetable }
}

extension GitWorktreeCreateTool {
    public var execution: AgentToolExecutionContract { .targetable }
}

extension GitWorktreeRemoveTool {
    public var execution: AgentToolExecutionContract { .targetable }
}

extension GitIntegrationPlanTool {
    public var execution: AgentToolExecutionContract { .targetable }
}

extension GitIntegrationPrepareTool {
    public var execution: AgentToolExecutionContract { .targetable }
}

extension GitIntegrationPromoteTool {
    public var execution: AgentToolExecutionContract { .targetable }
}

extension GitIntegrationCleanupTool {
    public var execution: AgentToolExecutionContract { .targetable }
}
