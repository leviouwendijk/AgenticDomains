import Agentic
import AgenticExecution
import AgenticWorkspace
import Foundation
import Interfaces
import Primitives

private struct GitWorkspaceExecution {
    let workspace: AgentWorkspace
    let repositoryRoot: URL

    static func resolve(
        _ context: AgentToolExecutionContext,
        toolName: String
    ) async throws -> Self {
        let workspace = try AgenticGitToolSupport.requireWorkspace(
            context.workspace,
            toolName: toolName
        )
        let repositoryRoot =
            context.workingDirectoryURL
                ?? workspace.rootURL

        try await AgenticGitToolSupport.requireRepositoryRoot(
            repositoryRoot,
            toolName: toolName
        )

        return .init(
            workspace: workspace,
            repositoryRoot: repositoryRoot
        )
    }
}

extension GitRepositoryStateTool:
    WorkspaceTargetableTool
{
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        _ = input
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: name
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths: [
                execution.repositoryRoot.path,
            ],
            summary:
                "Inspect Git repository state at the selected workspace location without fetching or mutation.",
            sideEffects: [],
            policyChecks: [
                "workspace_required",
                "workspace_target_authorized",
                "repository_root_working_directory",
                "no_fetch",
                "no_mutation",
            ]
        )
    }

    public func call(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        _ = input
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let state = try await GitManagerRepositoryInspector.state(
            at: execution.repositoryRoot,
            fetch: false
        )

        return try JSONToolBridge.encode(
            state
        )
    }
}

extension GitReconciliationPlanTool:
    WorkspaceTargetableTool
{
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        _ = input
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: name
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths: [
                execution.repositoryRoot.path,
            ],
            summary:
                "Diagnose Git reconciliation at the selected workspace location without fetching or applying changes.",
            sideEffects: [],
            policyChecks: [
                "workspace_required",
                "workspace_target_authorized",
                "repository_root_working_directory",
                "no_fetch",
                "no_mutation",
            ]
        )
    }

    public func call(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        _ = input
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let result = try await GitManagerReconciler.reconcile(
            at: execution.repositoryRoot,
            fetch: false,
            apply: false,
            cleanUntracked: false
        )

        return try JSONToolBridge.encode(
            result
        )
    }
}

extension GitDiffTool:
    WorkspaceTargetableTool
{
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let decoded = try JSONToolBridge.decode(
            GitDiffToolInput.self,
            from: input
        )
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: name
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths: decoded.paths,
            summary:
                "Observe \(decoded.scope.rawValue) tracked Git differences at the selected workspace location.",
            sideEffects: [],
            policyChecks: [
                "workspace_required",
                "workspace_target_authorized",
                "repository_root_working_directory",
                "typed_git_diff",
                "no_fetch",
                "no_mutation",
                "tracked_content_only",
            ]
        )
    }

    public func call(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            GitDiffToolInput.self,
            from: input
        )
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let result = try await GitManagerDiff.observe(
            decoded.request,
            at: execution.repositoryRoot
        )

        return try JSONToolBridge.encode(
            result
        )
    }
}

private extension GitPrepareCommitToolInput {
    func validatedPaths(
        in workspace: AgentWorkspace,
        repositoryRoot: URL
    ) throws -> [String] {
        let normalized = paths
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }

        guard !normalized.isEmpty else {
            throw GitManagerError.unsafeSync(
                "git_prepare_commit requires at least one explicit repository-relative path."
            )
        }

        let workspaceComponents =
            workspace.rootURL
                .standardizedFileURL
                .pathComponents
        let repositoryComponents =
            repositoryRoot
                .standardizedFileURL
                .pathComponents

        guard repositoryComponents.starts(
            with: workspaceComponents
        ) else {
            throw GitManagerError.unsafeSync(
                "git_prepare_commit selected repository root is outside the attached Agentic workspace."
            )
        }

        let repositoryPrefix = repositoryComponents
            .dropFirst(
                workspaceComponents.count
            )
            .joined(
                separator: "/"
            )

        for path in normalized {
            let components = path.split(
                separator: "/",
                omittingEmptySubsequences: false
            )

            guard !path.hasPrefix("/"),
                  !components.contains("..")
            else {
                throw GitManagerError.unsafeSync(
                    "git_prepare_commit paths must be repository-relative and cannot contain parent traversal: \(path)"
                )
            }

            let workspaceRelativePath =
                repositoryPrefix.isEmpty
                    ? path
                    : "\(repositoryPrefix)/\(path)"

            _ = try workspace.resolve(
                workspaceRelativePath
            )
        }

        return normalized
    }
}

extension GitPrepareCommitTool:
    WorkspaceTargetableTool
{
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let decoded = try JSONToolBridge.decode(
            GitPrepareCommitToolInput.self,
            from: input
        )
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let paths = try decoded.validatedPaths(
            in: execution.workspace,
            repositoryRoot: execution.repositoryRoot
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths: paths,
            summary:
                "Stage \(paths.count) explicit repository path(s) at the selected workspace location for a later commit.",
            sideEffects: [
                "modify the Git index",
                "does not create a commit",
                "does not push to a remote",
            ],
            policyChecks: [
                "workspace_required",
                "workspace_target_authorized",
                "repository_root_working_directory",
                "explicit_stage_paths",
                "workspace_paths_resolved",
                "typed_git_prepare_commit",
                "no_commit",
                "no_push",
            ]
        )
    }

    public func call(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            GitPrepareCommitToolInput.self,
            from: input
        )
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let paths = try decoded.validatedPaths(
            in: execution.workspace,
            repositoryRoot: execution.repositoryRoot
        )
        let output = try await GitManagerAction.prepareCommit(
            paths: paths,
            at: execution.repositoryRoot
        )
        let staged = try await GitManagerDiff.observe(
            .init(
                scope: .staged
            ),
            at: execution.repositoryRoot
        )
        let stagedPaths = Array(
            Set(
                staged.sections.flatMap {
                    $0.changedPaths
                }
            )
        ).sorted()

        return try JSONToolBridge.encode(
            GitPrepareCommitToolOutput(
                requestedPaths: paths,
                stagedPaths: stagedPaths,
                output: output
            )
        )
    }
}

extension GitCommitPreparedTool:
    WorkspaceTargetableTool
{
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let decoded = try JSONToolBridge.decode(
            GitCommitPreparedToolInput.self,
            from: input
        )
        let message = try decoded.validatedMessage()
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let paths = try await targetedStagedPaths(
            at: execution.repositoryRoot
        )

        guard !paths.isEmpty else {
            throw GitManagerError.unsafeSync(
                "git_commit_prepared requires staged changes. Run git_prepare_commit first."
            )
        }

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths: paths,
            summary:
                "Create a local commit from \(paths.count) staged path(s) at the selected workspace location with message: \(message)",
            sideEffects: [
                "create a Git commit from the current staged index",
                "does not stage additional paths",
                "does not push to a remote",
            ],
            policyChecks: [
                "workspace_required",
                "workspace_target_authorized",
                "repository_root_working_directory",
                "nonempty_commit_message",
                "staged_changes_required",
                "typed_git_commit_prepared",
                "no_implicit_stage",
                "no_push",
            ]
        )
    }

    public func call(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            GitCommitPreparedToolInput.self,
            from: input
        )
        let message = try decoded.validatedMessage()
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let paths = try await targetedStagedPaths(
            at: execution.repositoryRoot
        )

        guard !paths.isEmpty else {
            throw GitManagerError.unsafeSync(
                "git_commit_prepared requires staged changes. Run git_prepare_commit first."
            )
        }

        let output = try await GitManagerAction.commitPrepared(
            message: message,
            at: execution.repositoryRoot
        )
        let state = try await GitManagerRepositoryInspector.state(
            at: execution.repositoryRoot,
            fetch: false
        )

        return try JSONToolBridge.encode(
            GitCommitPreparedToolOutput(
                message: message,
                branch: state.branch,
                committedPaths: paths,
                output: output
            )
        )
    }

    private func targetedStagedPaths(
        at root: URL
    ) async throws -> [String] {
        let staged = try await GitManagerDiff.observe(
            .init(
                scope: .staged
            ),
            at: root
        )

        return Array(
            Set(
                staged.sections.flatMap {
                    $0.changedPaths
                }
            )
        ).sorted()
    }
}

private struct TargetedGitPullContext {
    let execution: GitWorkspaceExecution
    let state: GitManagerRepositoryState
    let remote: String
    let upstreamBranch: String
    let currentBranch: String
}

private func targetedGitPullContext(
    _ context: AgentToolExecutionContext,
    toolName: String
) async throws -> TargetedGitPullContext {
    let execution = try await GitWorkspaceExecution.resolve(
        context,
        toolName: toolName
    )
    let state = try await GitManagerRepositoryInspector.state(
        at: execution.repositoryRoot,
        fetch: false
    )

    guard !state.hasTrackedChanges else {
        throw GitManagerError.unsafeSync(
            "git_pull requires a clean tracked working tree. Commit, stash, or otherwise resolve tracked changes first."
        )
    }

    guard !state.hasUntracked else {
        throw GitManagerError.unsafeSync(
            "git_pull requires a clean repository with no untracked files. Resolve or remove untracked files first."
        )
    }

    guard let currentBranch = state.branch,
          !currentBranch.isEmpty
    else {
        throw GitManagerError.unsafeSync(
            "git_pull requires a current local branch and does not operate from detached HEAD."
        )
    }

    guard let remote = state.remote,
          !remote.isEmpty,
          let upstreamBranch = state.upstreamBranch,
          !upstreamBranch.isEmpty
    else {
        throw GitManagerError.unsafeSync(
            "git_pull requires an actually configured upstream for the current branch. It does not fall back to origin/HEAD or another default destination."
        )
    }

    return .init(
        execution: execution,
        state: state,
        remote: remote,
        upstreamBranch: upstreamBranch,
        currentBranch: currentBranch
    )
}

extension GitPullTool:
    WorkspaceTargetableTool
{
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        _ = input
        let pull = try await targetedGitPullContext(
            context,
            toolName: name
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: pull.execution.workspace.rootURL.path,
            targetPaths: [
                pull.execution.repositoryRoot.path,
            ],
            summary:
                "Fast-forward pull current branch \(pull.currentBranch) from configured upstream \(pull.remote)/\(pull.upstreamBranch) at the selected workspace location.",
            sideEffects: [
                "perform a network Git pull",
                "fetch and fast-forward from \(pull.remote)/\(pull.upstreamBranch)",
                "update the current branch and working tree only when fast-forwardable",
                "does not force",
                "does not rebase",
                "does not create a merge commit",
                "does not check out or switch branches",
            ],
            policyChecks: [
                "workspace_required",
                "workspace_target_authorized",
                "repository_root_working_directory",
                "clean_tracked_worktree_required",
                "no_untracked_files_required",
                "current_branch_required",
                "configured_upstream_required",
                "exact_pull_target_resolved",
                "typed_git_pull",
                "fast_forward_only",
                "no_force",
                "no_rebase",
                "no_merge_commit",
                "no_branch_checkout",
                "privileged_network_mutation",
            ]
        )
    }

    public func call(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        _ = input
        let pull = try await targetedGitPullContext(
            context,
            toolName: name
        )
        let output = try await GitManagerAction.pull(
            remote: pull.remote,
            branch: pull.upstreamBranch,
            at: pull.execution.repositoryRoot
        )
        let after = try await GitManagerRepositoryInspector.state(
            at: pull.execution.repositoryRoot,
            fetch: false
        )

        return try JSONToolBridge.encode(
            GitPullToolOutput(
                remote: pull.remote,
                upstreamBranch: pull.upstreamBranch,
                currentBranch: pull.currentBranch,
                beforeHead: pull.state.localHead,
                afterHead: after.localHead,
                changed:
                    pull.state.localHead
                        != after.localHead,
                output: output
            )
        )
    }
}

extension GitPushTool:
    WorkspaceTargetableTool
{
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let decoded = try JSONToolBridge.decode(
            GitPushToolInput.self,
            from: input
        )
        let target = try decoded.validatedTarget()
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let state = try await GitManagerRepositoryInspector.state(
            at: execution.repositoryRoot,
            fetch: false
        )
        let destination =
            target.map {
                "\($0.remote)/\($0.branch)"
            }
            ?? state.upstreamDisplay
            ?? "configured/default upstream"

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths: [
                execution.repositoryRoot.path,
            ],
            summary:
                "Push Git history from current branch \(state.branch ?? "unknown") to \(destination) at the selected workspace location.",
            sideEffects: [
                "perform a network Git push",
                target == nil
                    ? "use configured/default upstream resolution"
                    : "push to explicitly supplied remote and branch",
                target != nil && decoded.setUpstream
                    ? "set the explicit push destination as upstream"
                    : "do not change explicit upstream configuration",
            ],
            policyChecks: [
                "workspace_required",
                "workspace_target_authorized",
                "repository_root_working_directory",
                "remote_branch_pair_required",
                "push_target_syntax_validated",
                "typed_git_push",
                "no_branch_checkout",
                "privileged_network_mutation",
            ]
        )
    }

    public func call(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            GitPushToolInput.self,
            from: input
        )
        let target = try decoded.validatedTarget()
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let before = try await GitManagerRepositoryInspector.state(
            at: execution.repositoryRoot,
            fetch: false
        )
        let output: String

        if let target {
            output = try await GitManagerAction.push(
                remote: target.remote,
                branch: target.branch,
                setUpstream: decoded.setUpstream,
                at: execution.repositoryRoot
            )
        } else {
            output = try await GitManagerAction.push(
                at: execution.repositoryRoot
            )
        }

        return try JSONToolBridge.encode(
            GitPushToolOutput(
                remote: target?.remote,
                branch: target?.branch,
                configuredTarget:
                    target == nil
                        ? before.upstreamDisplay
                        : nil,
                currentBranch: before.branch,
                setUpstream:
                    target == nil
                        ? true
                        : decoded.setUpstream,
                output: output
            )
        )
    }
}
