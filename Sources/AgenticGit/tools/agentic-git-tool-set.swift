import Agentic

public struct AgenticGitToolProvider: AgentToolProvider {
    public init() {}

    public func registerTools(
        into registry: inout ToolRegistry
    ) throws {
        try registry.register(Git.Tools.RepositoryState())
        try registry.register(Git.Tools.Diff())
        try registry.register(Git.Tools.WorktreeList())
        try registry.register(Git.Tools.WorktreeCreate())
        try registry.register(Git.Tools.WorktreeRemove())
        try registry.register(Git.Tools.IntegrationPlan())
        try registry.register(Git.Tools.IntegrationPrepare())
        try registry.register(Git.Tools.IntegrationPromote())
        try registry.register(Git.Tools.IntegrationCleanup())
        try registry.register(Git.Tools.ReconciliationPlan())
        try registry.register(Git.Tools.Pull())
        try registry.register(Git.Tools.PrepareCommit())
        try registry.register(Git.Tools.CommitPrepared())
        try registry.register(Git.Tools.Push())
    }
}
