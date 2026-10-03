import Agentic

public struct AgenticGitToolProvider: AgentToolProvider {
    public init() {}

    public func registerTools(
        into registry: inout ToolRegistry
    ) throws {
        try registry.register(GitRepositoryStateTool(), execution: .targetable)
        try registry.register(Git.Tools.Diff(), execution: .targetable)
        try registry.register(GitWorktreeListTool(), execution: .targetable)
        try registry.register(GitWorktreeCreateTool(), execution: .targetable)
        try registry.register(GitWorktreeRemoveTool(), execution: .targetable)
        try registry.register(GitIntegrationPlanTool(), execution: .targetable)
        try registry.register(GitIntegrationPrepareTool(), execution: .targetable)
        try registry.register(GitIntegrationPromoteTool(), execution: .targetable)
        try registry.register(GitIntegrationCleanupTool(), execution: .targetable)
        try registry.register(GitReconciliationPlanTool(), execution: .targetable)
        try registry.register(GitPullTool(), execution: .targetable)
        try registry.register(Git.Tools.PrepareCommit(), execution: .targetable)
        try registry.register(Git.Tools.CommitPrepared(), execution: .targetable)
        try registry.register(Git.Tools.Push(), execution: .targetable)
    }
}