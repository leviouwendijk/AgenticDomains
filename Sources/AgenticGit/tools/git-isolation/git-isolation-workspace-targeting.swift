import Agentic
import AgenticExecution
import AgenticWorkspace
import Primitives

private func agenticGitScopedWorkspace(
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

extension GitWorktreeListTool: WorkspaceTargetableTool {
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        try await preflight(
            input: input,
            workspace: try await agenticGitScopedWorkspace(
                context,
                toolName: name
            )
        )
    }

    public func call(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        try await call(
            input: input,
            workspace: try await agenticGitScopedWorkspace(
                context,
                toolName: name
            )
        )
    }
}

extension GitWorktreeCreateTool: WorkspaceTargetableTool {
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        try await preflight(
            input: input,
            workspace: try await agenticGitScopedWorkspace(
                context,
                toolName: name
            )
        )
    }

    public func call(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        try await call(
            input: input,
            workspace: try await agenticGitScopedWorkspace(
                context,
                toolName: name
            )
        )
    }
}

extension GitWorktreeRemoveTool: WorkspaceTargetableTool {
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        try await preflight(
            input: input,
            workspace: try await agenticGitScopedWorkspace(
                context,
                toolName: name
            )
        )
    }

    public func call(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        try await call(
            input: input,
            workspace: try await agenticGitScopedWorkspace(
                context,
                toolName: name
            )
        )
    }
}

extension GitIntegrationPlanTool: WorkspaceTargetableTool {
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        try await preflight(
            input: input,
            workspace: try await agenticGitScopedWorkspace(
                context,
                toolName: name
            )
        )
    }

    public func call(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        try await call(
            input: input,
            workspace: try await agenticGitScopedWorkspace(
                context,
                toolName: name
            )
        )
    }
}

extension GitIntegrationPrepareTool: WorkspaceTargetableTool {
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        try await preflight(
            input: input,
            workspace: try await agenticGitScopedWorkspace(
                context,
                toolName: name
            )
        )
    }

    public func call(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        try await call(
            input: input,
            workspace: try await agenticGitScopedWorkspace(
                context,
                toolName: name
            )
        )
    }
}

extension GitIntegrationPromoteTool: WorkspaceTargetableTool {
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        try await preflight(
            input: input,
            workspace: try await agenticGitScopedWorkspace(
                context,
                toolName: name
            )
        )
    }

    public func call(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        try await call(
            input: input,
            workspace: try await agenticGitScopedWorkspace(
                context,
                toolName: name
            )
        )
    }
}

extension GitIntegrationCleanupTool: WorkspaceTargetableTool {
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        try await preflight(
            input: input,
            workspace: try await agenticGitScopedWorkspace(
                context,
                toolName: name
            )
        )
    }

    public func call(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        try await call(
            input: input,
            workspace: try await agenticGitScopedWorkspace(
                context,
                toolName: name
            )
        )
    }
}
