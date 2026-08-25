import Agentic

public struct AgenticGitToolSet: AgentToolSet {
    public init() {}

    public func register(
        into registry: inout ToolRegistry
    ) throws {
        try registry.register(
            [
                GitRepositoryStateTool(),
                GitReconciliationPlanTool(),
            ]
        )
    }
}
