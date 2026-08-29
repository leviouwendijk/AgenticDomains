import Agentic
import AgenticExecution
import AgenticWorkspace
import Foundation
import Interfaces
import Primitives
import Schema

/// Promote an exact prepared integration to a local target branch.
/// Interfaces requires the prepared integration worktree and target branch to remain unchanged
/// and performs only a fast-forward promotion.
@JSONSchema
public struct GitIntegrationPromoteToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Exact receipt returned by git_integration_prepare.
    public let executionReceipt: String

    /// Local target branch to advance to the exact prepared integration HEAD. Must exactly match the target ref reviewed by git_integration_plan.
    public let targetBranch: String

    public init(
        executionReceipt: String,
        targetBranch: String
    ) {
        self.executionReceipt = executionReceipt
        self.targetBranch = targetBranch
    }
}

public struct GitIntegrationPromoteTool: StaticAgentTool {
    public static let identifier: AgentToolIdentifier =
        "git_integration_promote"

    public static let description =
        "Promote a ready disposable integration to its reviewed target branch only when all exact-state and clean-worktree checks still hold. Never rebases, force-pushes, or resolves conflicts."

    public static let risk: ActionRisk = .privileged

    public static var inputSchema: JSONValue? {
        GitIntegrationPromoteToolInput.jsonschema.jsonvalue
    }

    public init() {}

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        let context = try await resolvedContext(
            input,
            workspace: workspace
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: context.workspace.rootURL.path,
            targetPaths: [context.workspace.rootURL.path]
                + (context.execution.worktree.map { [$0.path] } ?? []),
            summary: "Fast-forward local branch \(context.input.targetBranch) from exact target \(context.execution.plan.target.commit) to prepared integration \(context.execution.integrationHead ?? "missing").",
            estimatedWriteCount: 1,
            sideEffects: [
                "advance one local target branch only by fast-forward",
                "update its checked-out clean working tree when the branch is occupied",
                "fail closed if source, target, integration HEAD, or worktree state is stale",
                "does not rebase",
                "does not resolve conflicts",
                "does not push",
            ],
            policyChecks: [
                "workspace_required",
                "repository_root_workspace",
                "typed_integration_execution_receipt",
                "agentic_managed_integration_worktree",
                "integration_ready_required",
                "integration_head_exact",
                "integration_worktree_clean",
                "target_branch_matches_planned_target_ref",
                "target_head_exact",
                "target_worktree_clean_when_occupied",
                "fast_forward_only",
                "no_rebase",
                "no_conflict_resolution",
                "no_push",
            ]
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let context = try await resolvedContext(
            input,
            workspace: workspace
        )

        return try JSONToolBridge.encode(
            try await GitManagerIntegrationExecutor.promote(
                context.execution,
                targetBranch: context.input.targetBranch,
                at: context.workspace.rootURL
            )
        )
    }
}

private extension GitIntegrationPromoteTool {
    struct Context {
        let input: GitIntegrationPromoteToolInput
        let workspace: AgentWorkspace
        let execution: GitManagerIntegrationExecution
    }

    func resolvedContext(
        _ input: JSONValue,
        workspace candidate: AgentWorkspace?
    ) async throws -> Context {
        let decoded = try JSONToolBridge.decode(
            GitIntegrationPromoteToolInput.self,
            from: input
        )
        let workspace = try AgenticGitToolSupport.requireWorkspace(
            candidate,
            toolName: name
        )

        try await AgenticGitToolSupport.requireRepositoryRoot(
            workspace,
            toolName: name
        )

        let execution = try AgenticGitIntegrationReceipt.decode(
            GitManagerIntegrationExecution.self,
            from: decoded.executionReceipt
        )

        guard decoded.targetBranch == execution.plan.target.ref else {
            throw GitManagerError.unsafeSync(
                "git_integration_promote targetBranch must exactly match the target ref reviewed in the integration plan: \(execution.plan.target.ref)"
            )
        }

        if let worktree = execution.worktree {
            _ = try AgenticGitManagedWorktrees.requireManaged(
                worktree,
                repository: workspace.rootURL,
                kind: .integration
            )
        }

        return .init(
            input: decoded,
            workspace: workspace,
            execution: execution
        )
    }
}

/// Remove the disposable integration worktree and branch represented by a preparation receipt.
/// Without discard, Interfaces only cleans a successful integration already contained in the target.
/// Conflict or abandoned cleanup requires discard=true.
@JSONSchema
public struct GitIntegrationCleanupToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Exact receipt returned by git_integration_prepare.
    public let executionReceipt: String

    /// Explicitly discard an unpromoted or conflicted disposable integration. Defaults to false.
    public let discard: Bool?

    public init(
        executionReceipt: String,
        discard: Bool? = nil
    ) {
        self.executionReceipt = executionReceipt
        self.discard = discard
    }

    var resolvedDiscard: Bool {
        discard ?? false
    }
}

public struct GitIntegrationCleanupToolOutput:
    Sendable,
    Codable,
    Hashable
{
    public let status: String
    public let worktree: String?
    public let discarded: Bool

    public init(
        status: String,
        worktree: String?,
        discarded: Bool
    ) {
        self.status = status
        self.worktree = worktree
        self.discarded = discarded
    }
}

public struct GitIntegrationCleanupTool: StaticAgentTool {
    public static let identifier: AgentToolIdentifier =
        "git_integration_cleanup"

    public static let description =
        "Clean up only an Agentic-managed disposable integration worktree and its integration branch. The original task/source branch is never deleted. Explicit discard is required for conflicted or unpromoted state."

    public static let risk: ActionRisk = .privileged

    public static var inputSchema: JSONValue? {
        GitIntegrationCleanupToolInput.jsonschema.jsonvalue
    }

    public init() {}

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        let context = try await resolvedContext(
            input,
            workspace: workspace
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: context.workspace.rootURL.path,
            targetPaths: context.execution.worktree.map { [$0.path] } ?? [],
            summary: context.input.resolvedDiscard
                ? "Explicitly discard disposable integration state \(context.execution.integrationBranch ?? "none")."
                : "Clean disposable integration state only after Interfaces proves the prepared integration is incorporated into its target.",
            estimatedWriteCount: context.execution.worktree == nil ? 0 : 1,
            sideEffects: [
                "remove only the disposable Agentic-managed integration worktree",
                "delete only the disposable integration branch",
                "preserve the original source/task branch",
                context.input.resolvedDiscard
                    ? "explicitly discard unpromoted or conflicted disposable integration state"
                    : "refuse cleanup until the prepared integration is contained in the target",
                "does not push",
            ],
            policyChecks: [
                "workspace_required",
                "repository_root_workspace",
                "typed_integration_execution_receipt",
                "agentic_managed_integration_worktree",
                "source_branch_preserved",
                context.input.resolvedDiscard
                    ? "explicit_discard_requested"
                    : "integration_must_be_incorporated",
                "no_push",
            ]
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let context = try await resolvedContext(
            input,
            workspace: workspace
        )
        let worktree = context.execution.worktree?.path

        try await GitManagerIntegrationExecutor.cleanup(
            context.execution,
            discard: context.input.resolvedDiscard,
            at: context.workspace.rootURL
        )

        return try JSONToolBridge.encode(
            GitIntegrationCleanupToolOutput(
                status: "cleaned",
                worktree: worktree,
                discarded: context.input.resolvedDiscard
            )
        )
    }
}

private extension GitIntegrationCleanupTool {
    struct Context {
        let input: GitIntegrationCleanupToolInput
        let workspace: AgentWorkspace
        let execution: GitManagerIntegrationExecution
    }

    func resolvedContext(
        _ input: JSONValue,
        workspace candidate: AgentWorkspace?
    ) async throws -> Context {
        let decoded = try JSONToolBridge.decode(
            GitIntegrationCleanupToolInput.self,
            from: input
        )
        let workspace = try AgenticGitToolSupport.requireWorkspace(
            candidate,
            toolName: name
        )

        try await AgenticGitToolSupport.requireRepositoryRoot(
            workspace,
            toolName: name
        )

        let execution = try AgenticGitIntegrationReceipt.decode(
            GitManagerIntegrationExecution.self,
            from: decoded.executionReceipt
        )

        if let worktree = execution.worktree {
            _ = try AgenticGitManagedWorktrees.requireManaged(
                worktree,
                repository: workspace.rootURL,
                kind: .integration
            )
        }

        return .init(
            input: decoded,
            workspace: workspace,
            execution: execution
        )
    }
}
