import Agentic
import AgenticExecution
import AgenticWorkspace
import Foundation
import Interfaces
import Primitives
import Schema

/// Analyze integration of one Git source ref into one target ref without mutating either ref or worktree.
@JSONSchema
public struct GitIntegrationPlanToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Source branch, commit, or other Git ref to integrate.
    public let sourceRef: String

    /// Target branch, commit, or other Git ref to receive the source.
    public let targetRef: String

    /// Optional previously observed exact target commit. Drift is reported in the plan.
    public let expectedTargetCommit: String?

    public init(
        sourceRef: String,
        targetRef: String,
        expectedTargetCommit: String? = nil
    ) {
        self.sourceRef = sourceRef
        self.targetRef = targetRef
        self.expectedTargetCommit = expectedTargetCommit
    }
}

public struct GitIntegrationPlanToolOutput:
    Sendable,
    Codable,
    Hashable
{
    public let plan: GitManagerIntegrationPlan
    public let receipt: String

    public init(
        plan: GitManagerIntegrationPlan,
        receipt: String
    ) {
        self.plan = plan
        self.receipt = receipt
    }
}

public struct GitIntegrationPlanTool: StaticAgentTool {
    public static let identifier: AgentToolIdentifier =
        "git_integration_plan"

    public static let description =
        "Build an immutable, non-mutating Git integration plan with exact source and target commits, drift detection, changed-path overlap, and merge conflict classification."

    public static let risk: ActionRisk = .observe

    public static var inputSchema: JSONValue? {
        GitIntegrationPlanToolInput.jsonschema.jsonvalue
    }

    public init() {}

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        let context = try await resolved(
            input,
            workspace: workspace
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: context.workspace.rootURL.path,
            targetPaths: context.plan.overlappingPaths,
            summary: "Plan \(context.plan.source.ref) -> \(context.plan.target.ref): \(context.plan.classification.rawValue), source \(context.plan.source.commit), target \(context.plan.target.commit), targetDrifted=\(context.plan.targetDrifted).",
            sideEffects: [],
            policyChecks: [
                "workspace_required",
                "repository_root_workspace",
                "typed_git_integration_plan",
                "exact_source_commit",
                "exact_target_commit",
                "merge_base_analysis",
                "merge_tree_conflict_analysis",
                "no_fetch",
                "no_mutation",
            ]
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let context = try await resolved(
            input,
            workspace: workspace
        )
        let receipt = try AgenticGitIntegrationReceipt.encode(
            context.plan
        )

        return try JSONToolBridge.encode(
            GitIntegrationPlanToolOutput(
                plan: context.plan,
                receipt: receipt
            )
        )
    }
}

private extension GitIntegrationPlanTool {
    struct Context {
        let workspace: AgentWorkspace
        let plan: GitManagerIntegrationPlan
    }

    func resolved(
        _ input: JSONValue,
        workspace candidate: AgentWorkspace?
    ) async throws -> Context {
        let decoded = try JSONToolBridge.decode(
            GitIntegrationPlanToolInput.self,
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

        let plan = try await GitManagerIntegrationPlanner.plan(
            sourceRef: decoded.sourceRef,
            targetRef: decoded.targetRef,
            expectedTargetCommit: decoded.expectedTargetCommit,
            at: workspace.rootURL
        )

        return .init(
            workspace: workspace,
            plan: plan
        )
    }
}

/// Prepare a previously planned integration in a disposable Agentic-managed integration worktree.
/// Interfaces revalidates exact source and target commits before merging.
@JSONSchema
public struct GitIntegrationPrepareToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Exact receipt returned by git_integration_plan.
    public let planReceipt: String

    /// Stable semantic identity for this integration attempt.
    public let semanticKey: String

    public init(
        planReceipt: String,
        semanticKey: String
    ) {
        self.planReceipt = planReceipt
        self.semanticKey = semanticKey
    }
}

public struct GitIntegrationPrepareToolOutput:
    Sendable,
    Codable,
    Hashable
{
    public let execution: GitManagerIntegrationExecution
    public let receipt: String

    public init(
        execution: GitManagerIntegrationExecution,
        receipt: String
    ) {
        self.execution = execution
        self.receipt = receipt
    }
}

public struct GitIntegrationPrepareTool: StaticAgentTool {
    public static let identifier: AgentToolIdentifier =
        "git_integration_prepare"

    public static let description =
        "Revalidate an immutable integration plan and perform the merge only inside a disposable Agentic-managed integration worktree. Canonical target and source branches remain untouched."

    public static let risk: ActionRisk = .boundedmutate

    public static var inputSchema: JSONValue? {
        GitIntegrationPrepareToolInput.jsonschema.jsonvalue
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
            targetPaths: [context.destination.path],
            summary: "Prepare \(context.current.source.ref) -> \(context.current.target.ref) as \(context.current.classification.rawValue) in disposable integration worktree \(context.destination.path).",
            estimatedWriteCount: 1,
            sideEffects: [
                "create one disposable local integration branch",
                "create one Agentic-managed integration worktree",
                "attempt the planned merge only inside that worktree",
                "retain conflicts inside the disposable worktree when present",
                "does not move the target branch",
                "does not modify the source branch",
                "does not push",
            ],
            policyChecks: [
                "workspace_required",
                "repository_root_workspace",
                "typed_integration_plan_receipt",
                "semantic_isolation_id",
                "agentic_managed_integration_destination",
                "source_state_revalidated",
                "target_state_revalidated",
                "disposable_merge_only",
                "no_target_branch_move",
                "no_source_branch_move",
                "no_push",
            ]
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            GitIntegrationPrepareToolInput.self,
            from: input
        )
        let workspace = try AgenticGitToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )

        try await AgenticGitToolSupport.requireRepositoryRoot(
            workspace,
            toolName: name
        )

        let plan = try AgenticGitIntegrationReceipt.decode(
            GitManagerIntegrationPlan.self,
            from: decoded.planReceipt
        )
        let isolationID = try GitManagerIsolationID(
            decoded.semanticKey
        )
        let destination = try AgenticGitManagedWorktrees.destination(
            repository: workspace.rootURL,
            isolationID: isolationID,
            kind: .integration
        )

        try AgenticGitManagedWorktrees.ensureParent(
            for: destination
        )

        let execution = try await GitManagerIntegrationExecutor.prepare(
            plan,
            isolationID: isolationID,
            destination: destination,
            at: workspace.rootURL
        )
        let receipt = try AgenticGitIntegrationReceipt.encode(
            execution
        )

        return try JSONToolBridge.encode(
            GitIntegrationPrepareToolOutput(
                execution: execution,
                receipt: receipt
            )
        )
    }
}

private extension GitIntegrationPrepareTool {
    struct Context {
        let workspace: AgentWorkspace
        let current: GitManagerIntegrationPlan
        let destination: URL
    }

    func resolvedContext(
        _ input: JSONValue,
        workspace candidate: AgentWorkspace?
    ) async throws -> Context {
        let decoded = try JSONToolBridge.decode(
            GitIntegrationPrepareToolInput.self,
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

        let plan = try AgenticGitIntegrationReceipt.decode(
            GitManagerIntegrationPlan.self,
            from: decoded.planReceipt
        )
        let current = try await GitManagerIntegrationPlanner.plan(
            sourceRef: plan.source.ref,
            targetRef: plan.target.ref,
            expectedTargetCommit: plan.expectedTargetCommit,
            at: workspace.rootURL
        )

        guard current.source.commit == plan.source.commit else {
            throw GitManagerIntegrationExecutionError.staleSource(
                expected: plan.source.commit,
                actual: current.source.commit
            )
        }

        guard current.target.commit == plan.target.commit else {
            throw GitManagerIntegrationExecutionError.staleTarget(
                expected: plan.target.commit,
                actual: current.target.commit
            )
        }

        let isolationID = try GitManagerIsolationID(
            decoded.semanticKey
        )
        let destination = try AgenticGitManagedWorktrees.destination(
            repository: workspace.rootURL,
            isolationID: isolationID,
            kind: .integration
        )

        return .init(
            workspace: workspace,
            current: current,
            destination: destination
        )
    }
}
