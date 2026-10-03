import Agentic
import Workspace
import Foundation
import Interfaces
import Primitives

struct GitWorkspaceExecution {
    let workspace: WorkspaceContext
    let repositoryRoot: URL

    static func resolve(
        _ context: WorkspaceContext?,
        toolName: String
    ) async throws -> Self {
        let workspace = try AgenticGitToolSupport.requireWorkspace(
            context,
            toolName: toolName
        )
        let repositoryRoot = workspace.absoluteURL

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

extension GitRepositoryStateTool {
    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        _ = input
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )

        return .init(
            tool: Self.definition.identifier,
            risk: risk,
            summary:
                "Inspect Git repository state at the selected workspace location without fetching or mutation.",
            access: .init(
                targets: [
                    execution.repositoryRoot.path,
                ]
            ),
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
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        _ = input
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let state = try await GitManagerRepositoryInspector.state(
            at: execution.repositoryRoot,
            fetch: false
        )

        return state
    }
}

extension GitReconciliationPlanTool {
    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        _ = input
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )

        return .init(
            tool: Self.definition.identifier,
            risk: risk,
            summary:
                "Diagnose Git reconciliation at the selected workspace location without fetching or applying changes.",
            access: .init(
                targets: [
                    execution.repositoryRoot.path,
                ]
            ),
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
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        _ = input
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let result = try await GitManagerReconciler.reconcile(
            at: execution.repositoryRoot,
            fetch: false,
            apply: false,
            cleanUntracked: false
        )

        return result
    }
}

extension Git.Tools.Diff {
    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        _ = try await GitWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )

        return .init(
            tool: Self.definition.identifier,
            risk: risk,
            summary:
                "Observe \(input.scope.rawValue) tracked Git differences at the selected workspace location.",
            access: .init(
                targets: input.paths
            ),
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
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let result = try await GitManagerDiff.observe(
            input.request,
            at: execution.repositoryRoot
        )

        return result
    }
}

private extension GitPrepareCommitToolInput {
    func validatedPaths(
        in workspace: WorkspaceContext,
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
            workspace.absoluteURL
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

            _ = try workspace.authorize(
                workspaceRelativePath,
                capability: .write
            )
        }

        return normalized
    }
}

extension Git.Tools.PrepareCommit {
    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let paths = try input.validatedPaths(
            in: execution.workspace,
            repositoryRoot: execution.repositoryRoot
        )

        return .init(
            tool: Self.definition.identifier,
            risk: risk,
            summary:
                "Stage \(paths.count) explicit repository path(s) at the selected workspace location for a later commit.",
            access: .init(
                targets: paths
            ),
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
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let paths = try input.validatedPaths(
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

        return GitPrepareCommitToolOutput(
                requestedPaths: paths,
                stagedPaths: stagedPaths,
                output: output
            )
    }
}

extension Git.Tools.CommitPrepared {
    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        let message = try input.validatedMessage()
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
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
            tool: Self.definition.identifier,
            risk: risk,
            summary:
                "Create a local commit from \(paths.count) staged path(s) at the selected workspace location with message: \(message)",
            access: .init(
                targets: paths
            ),
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
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let message = try input.validatedMessage()
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
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

        return GitCommitPreparedToolOutput(
                message: message,
                branch: state.branch,
                committedPaths: paths,
                output: output
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
    _ context: WorkspaceContext?,
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

extension GitPullTool {
    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        _ = input
        let pull = try await targetedGitPullContext(
            context,
            toolName: Self.definition.identifier.rawValue
        )

        return .init(
            tool: Self.definition.identifier,
            risk: risk,
            summary:
                "Fast-forward pull current branch \(pull.currentBranch) from configured upstream \(pull.remote)/\(pull.upstreamBranch) at the selected workspace location.",
            access: .init(
                targets: [
                    pull.execution.repositoryRoot.path,
                ]
            ),
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
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        _ = input
        let pull = try await targetedGitPullContext(
            context,
            toolName: Self.definition.identifier.rawValue
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

        let result = GitPullToolOutput(
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

        return result
    }
}

extension Git.Tools.Push {
    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        let target = try input.validatedTarget()
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
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
            tool: Self.definition.identifier,
            risk: risk,
            summary:
                "Push Git history from current branch \(state.branch ?? "unknown") to \(destination) at the selected workspace location.",
            access: .init(
                targets: [
                    execution.repositoryRoot.path,
                ]
            ),
            sideEffects: [
                "perform a network Git push",
                target == nil
                    ? "use configured/default upstream resolution"
                    : "push to explicitly supplied remote and branch",
                target != nil && input.setUpstream
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
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let target = try input.validatedTarget()
        let execution = try await GitWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
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
                setUpstream: input.setUpstream,
                at: execution.repositoryRoot
            )
        } else {
            output = try await GitManagerAction.push(
                at: execution.repositoryRoot
            )
        }

        return GitPushToolOutput(
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
                        : input.setUpstream,
                output: output
            )
    }
}


extension Git.Tools.CommitPrepared {
    public func process(
        _ output: Output,
        input _: Input
    ) -> ToolCall.ResultProjection? {
        .init(
            status: "passed",
            summary: "Created local Git commit: \(output.message)",
            facts: [
                .init(label: "message", value: output.message),
                .init(label: "branch", value: output.branch ?? "unknown"),
                .init(label: "paths", value: output.committedPaths.joined(separator: ", ")),
            ]
        )
    }
}

extension GitPullTool {
    public func process(
        _ output: Output,
        input _: Input
    ) -> ToolCall.ResultProjection? {
        var facts: [ToolCall.ResultProjection.Fact] = [
            .init(label: "branch", value: output.currentBranch),
            .init(label: "upstream", value: "\(output.remote)/\(output.upstreamBranch)"),
        ]
        if let afterHead = output.afterHead {
            facts.append(.init(label: "HEAD", value: afterHead))
        }
        return .init(
            status: output.changed ? "updated" : "up to date",
            summary: "\(output.currentBranch) <- \(output.remote)/\(output.upstreamBranch)",
            facts: facts
        )
    }
}
