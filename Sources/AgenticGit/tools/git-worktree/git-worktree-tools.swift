import Agentic
import AgenticExecution
import AgenticWorkspace
import Foundation
import Interfaces
import Primitives
import Schema
import SchemaMacros

public struct GitWorktreeListTool: AgentTool {
    public typealias Input = AgenticGitEmptyToolInput
    public typealias Output = [GitManagerWorktreeRecord]
    public static let identifier: AgentToolIdentifier =
        "git_worktree_list"

    public static let description =
        "List Git worktrees for the current Agentic workspace repository without mutating the repository."

    public static let risk: ActionRisk = .observe

    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init() {}

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let workspace = try await agenticGitScopedWorkspace(
            context,
            toolName: name
        )

        try await AgenticGitToolSupport.requireRepositoryRoot(
            workspace,
            toolName: name
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: context.workspace?.rootURL.path,
            targetPaths: [workspace.rootURL.path],
            summary: "List Git worktrees for the current repository.",
            sideEffects: [],
            policyChecks: [
                "workspace_required",
                "repository_root_workspace",
                "typed_git_worktree_list",
                "no_mutation",
            ]
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let workspace = try await agenticGitScopedWorkspace(
            context,
            toolName: name
        )

        try await AgenticGitToolSupport.requireRepositoryRoot(
            workspace,
            toolName: name
        )

        return try await GitManagerWorktree.list(
                at: workspace.rootURL
            )
    }
}

/// Create an Agentic-managed isolated Git worktree on a new semantic branch.
/// The destination path is derived by Agentic and cannot be supplied directly.
@JSONSchema
public struct GitWorktreeCreateToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Stable semantic identity for the isolated task or pass.
    public let semanticKey: String

    /// Git ref to isolate from. Defaults to HEAD.
    public let baseRef: String?

    public init(
        semanticKey: String,
        baseRef: String? = nil
    ) {
        self.semanticKey = semanticKey
        self.baseRef = baseRef
    }

    func isolationID() throws -> GitManagerIsolationID {
        try GitManagerIsolationID(
            semanticKey
        )
    }

    var resolvedBaseRef: String {
        let trimmed = baseRef?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmed?.isEmpty == false
            ? trimmed!
            : "HEAD"
    }
}

public struct GitWorktreeCreateToolOutput:
    Sendable,
    Codable,
    Hashable
{
    public let isolationID: GitManagerIsolationID
    public let branch: String
    public let result: GitManagerWorktreeCreateResult

    public init(
        isolationID: GitManagerIsolationID,
        branch: String,
        result: GitManagerWorktreeCreateResult
    ) {
        self.isolationID = isolationID
        self.branch = branch
        self.result = result
    }
}

public struct GitWorktreeCreateTool: AgentTool {
    public typealias Input = GitWorktreeCreateToolInput
    public typealias Output = GitWorktreeCreateToolOutput

    public static let identifier: AgentToolIdentifier =
        "git_worktree_create"

    public static let description =
        "Create an isolated Agentic-managed Git worktree and durable semantic branch from an exact resolved base commit. The model does not choose the filesystem destination."

    public static let risk: ActionRisk = .boundedmutate

    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init() {}

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let workspace = try await agenticGitScopedWorkspace(
            context,
            toolName: name
        )

        try await AgenticGitToolSupport.requireRepositoryRoot(
            workspace,
            toolName: name
        )

        let isolationID = try input.isolationID()
        let branch = isolationID.branchName()
        let destination = try AgenticGitManagedWorktrees.destination(
            repository: workspace.rootURL,
            isolationID: isolationID,
            kind: .task
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: context.workspace?.rootURL.path,
            targetPaths: [destination.path],
            summary: "Create isolated branch \(branch) from \(input.resolvedBaseRef) in Agentic-managed worktree \(destination.path).",
            estimatedWriteCount: 1,
            sideEffects: [
                "create one local Git branch",
                "create one linked Git worktree outside the canonical checkout",
                "does not modify the canonical branch or working tree",
                "does not push",
            ],
            policyChecks: [
                "workspace_required",
                "repository_root_workspace",
                "semantic_isolation_id",
                "agentic_managed_worktree_destination",
                "typed_git_worktree_create",
                "new_branch_only",
                "no_force",
                "no_push",
            ]
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let workspace = try await agenticGitScopedWorkspace(
            context,
            toolName: name
        )

        try await AgenticGitToolSupport.requireRepositoryRoot(
            workspace,
            toolName: name
        )

        let isolationID = try input.isolationID()
        let branch = isolationID.branchName()
        let destination = try AgenticGitManagedWorktrees.destination(
            repository: workspace.rootURL,
            isolationID: isolationID,
            kind: .task
        )

        try AgenticGitManagedWorktrees.ensureParent(
            for: destination
        )

        let result = try await GitManagerWorktree.create(
            .init(
                repository: workspace.rootURL,
                destination: destination,
                baseRef: input.resolvedBaseRef,
                checkout: .newBranch(branch)
            )
        )

        return GitWorktreeCreateToolOutput(
                isolationID: isolationID,
                branch: branch,
                result: result
            )
    }
}

/// Remove one Agentic-managed task worktree while preserving its branch.
/// Arbitrary worktree paths and forced removal are not exposed.
@JSONSchema
public struct GitWorktreeRemoveToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Exact path returned by git_worktree_create or git_worktree_list for an Agentic-managed task worktree.
    public let path: String

    public init(
        path: String
    ) {
        self.path = path
    }
}

public struct GitWorktreeRemoveToolOutput:
    Sendable,
    Codable,
    Hashable
{
    public let path: String
    public let preservedBranch: String?

    public init(
        path: String,
        preservedBranch: String?
    ) {
        self.path = path
        self.preservedBranch = preservedBranch
    }
}

public struct GitWorktreeRemoveTool: AgentTool {
    public typealias Input = GitWorktreeRemoveToolInput
    public typealias Output = GitWorktreeRemoveToolOutput
    public static let identifier: AgentToolIdentifier =
        "git_worktree_remove"

    public static let description =
        "Remove one clean Agentic-managed task worktree without forcing removal and without deleting its durable branch."

    public static let risk: ActionRisk = .boundedmutate

    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init() {}

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let context = try await resolvedContext(
            input,
            workspace: try await agenticGitScopedWorkspace(
                context,
                toolName: name
            )
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: context.workspace.rootURL.path,
            targetPaths: [context.worktree.path.path],
            summary: "Remove Agentic-managed task worktree \(context.worktree.path.path) while preserving branch \(context.worktree.branch ?? "none").",
            estimatedWriteCount: 1,
            sideEffects: [
                "remove one linked Git worktree",
                "preserve the associated task branch",
                "refuse dirty worktree removal through Git's non-force semantics",
                "does not push",
            ],
            policyChecks: [
                "workspace_required",
                "repository_root_workspace",
                "agentic_managed_task_worktree",
                "worktree_must_exist",
                "primary_worktree_denied",
                "typed_git_worktree_remove",
                "no_force",
                "preserve_branch",
                "no_push",
            ]
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let context = try await resolvedContext(
            input,
            workspace: try await agenticGitScopedWorkspace(
                context,
                toolName: name
            )
        )

        try await GitManagerWorktree.remove(
            context.worktree.path,
            at: context.workspace.rootURL
        )

        return GitWorktreeRemoveToolOutput(
                path: context.worktree.path.path,
                preservedBranch: context.worktree.branch
            )
    }
}

private extension GitWorktreeRemoveTool {
    struct RemovalContext {
        let workspace: AgentWorkspace
        let worktree: GitManagerWorktreeRecord
    }

    func resolvedContext(
        _ input: GitWorktreeRemoveToolInput,
        workspace candidate: AgentWorkspace?
    ) async throws -> RemovalContext {
        let workspace = try AgenticGitToolSupport.requireWorkspace(
            candidate,
            toolName: name
        )

        try await AgenticGitToolSupport.requireRepositoryRoot(
            workspace,
            toolName: name
        )

        let path = try AgenticGitManagedWorktrees.requireManaged(
            input.path,
            repository: workspace.rootURL,
            kind: .task
        )

        guard let worktree = try await GitManagerWorktree.list(
            at: workspace.rootURL
        ).first(where: {
            $0.path == path
        }) else {
            throw GitManagerWorktreeError.worktreeNotFound(
                path.path
            )
        }

        guard !worktree.isPrimary else {
            throw GitManagerWorktreeError.primaryRemovalDenied(
                path.path
            )
        }

        return .init(
            workspace: workspace,
            worktree: worktree
        )
    }
}
