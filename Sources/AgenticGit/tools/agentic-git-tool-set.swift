import Agentic

public struct AgenticGitToolProvider: AgentToolProvider {
    public init() {}

    public func registerTools(
        into registry: inout ToolRegistry
    ) throws {
        try registry.register(Git.Tools.RepositoryState(), execution: .targetable)
        try registry.register(Git.Tools.Diff(), execution: .targetable)
        try registry.register(Git.Tools.WorktreeList(), execution: .targetable)
        try registry.register(Git.Tools.WorktreeCreate(), execution: .targetable)
        try registry.register(Git.Tools.WorktreeRemove(), execution: .targetable)
        try registry.register(Git.Tools.IntegrationPlan(), execution: .targetable)
        try registry.register(Git.Tools.IntegrationPrepare(), execution: .targetable)
        try registry.register(Git.Tools.IntegrationPromote(), execution: .targetable)
        try registry.register(Git.Tools.IntegrationCleanup(), execution: .targetable)
        try registry.register(Git.Tools.ReconciliationPlan(), execution: .targetable)
        try registry.register(Git.Tools.Pull(), execution: .targetable)
        try registry.register(Git.Tools.PrepareCommit(), execution: .targetable)
        try registry.register(Git.Tools.CommitPrepared(), execution: .targetable)
        try registry.register(Git.Tools.Push(), execution: .targetable)
    }
}
