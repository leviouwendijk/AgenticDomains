import AgenticExecution

public struct AgenticGitToolSet: AgentToolSet {
    public init() {}

    public func register(
        into registry: inout ToolRegistry
    ) throws {
        try registry.register {
            GitRepositoryStateTool()
            GitDiffTool()
            GitWorktreeListTool()
            GitWorktreeCreateTool()
            GitWorktreeRemoveTool()
            GitIntegrationPlanTool()
            GitIntegrationPrepareTool()
            GitIntegrationPromoteTool()
            GitIntegrationCleanupTool()
            GitReconciliationPlanTool()
            GitPullTool()
            GitPrepareCommitTool()
            GitCommitPreparedTool()
            GitPushTool()
        }
    }
}
