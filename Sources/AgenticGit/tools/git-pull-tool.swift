import Agentic
import Foundation
import Interfaces
import Primitives

public struct GitPullToolOutput:
    Sendable,
    Codable,
    Hashable
{
    public let remote: String
    public let upstreamBranch: String
    public let currentBranch: String
    public let beforeHead: String?
    public let afterHead: String?
    public let changed: Bool
    public let output: String

    public init(
        remote: String,
        upstreamBranch: String,
        currentBranch: String,
        beforeHead: String?,
        afterHead: String?,
        changed: Bool,
        output: String
    ) {
        self.remote = remote
        self.upstreamBranch = upstreamBranch
        self.currentBranch = currentBranch
        self.beforeHead = beforeHead
        self.afterHead = afterHead
        self.changed = changed
        self.output = output
    }
}

public struct GitPullTool:
    StaticAgentTool
{
    public static let identifier:
        AgentToolIdentifier =
            "git_pull"

    public static let description =
        """
        Fast-forward the current Agentic workspace Git repository from its configured upstream. Requires a clean repository, a current branch, and a configured upstream. Never forces, rebases, creates a merge commit, checks out, or changes branches.
        """

    public static let risk:
        ActionRisk =
            .privileged

    public static var inputSchema:
        JSONValue?
    {
        JSONSchema.object(
            description:
                """
                Pull the configured upstream for the current repository. This tool intentionally accepts no remote, branch, force, rebase, merge, or checkout parameters.
                """
        ) {}
    }

    public init() {}

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        _ = input

        let context = try await resolvedContext(
            workspace
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot:
                context.workspace.rootURL.path,
            summary:
                "Fast-forward pull current branch \(context.currentBranch) from configured upstream \(context.remote)/\(context.upstreamBranch).",
            sideEffects: [
                "perform a network Git pull",
                "fetch and fast-forward from \(context.remote)/\(context.upstreamBranch)",
                "update the current branch and working tree only when fast-forwardable",
                "does not force",
                "does not rebase",
                "does not create a merge commit",
                "does not check out or switch branches",
            ],
            policyChecks: [
                "workspace_required",
                "repository_root_workspace",
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
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        _ = input

        // Re-resolve every state-sensitive invariant at execution time.
        // Do not rely on a stale preflight snapshot.
        let context = try await resolvedContext(
            workspace
        )

        let output =
            try await GitManagerAction.pull(
                remote: context.remote,
                branch: context.upstreamBranch,
                at: context.workspace.rootURL
            )

        let after =
            try await GitManagerRepositoryInspector
                .state(
                    at: context.workspace.rootURL,
                    fetch: false
                )

        return try JSONToolBridge.encode(
            GitPullToolOutput(
                remote: context.remote,
                upstreamBranch:
                    context.upstreamBranch,
                currentBranch:
                    context.currentBranch,
                beforeHead:
                    context.state.localHead,
                afterHead:
                    after.localHead,
                changed:
                    context.state.localHead
                        != after.localHead,
                output: output
            )
        )
    }

    public func processResult(
        input _: JSONValue,
        output: JSONValue,
        workspace _: AgentWorkspace?
    ) -> AgentToolResultProcessing {
        guard let result =
            try? JSONToolBridge.decode(
                GitPullToolOutput.self,
                from: output
            )
        else {
            return .none
        }

        var facts: [AgentToolResultProjection.Fact] = [
            .init(
                label: "branch",
                value: result.currentBranch
            ),
            .init(
                label: "upstream",
                value:
                    "\(result.remote)/\(result.upstreamBranch)"
            ),
        ]

        if let afterHead = result.afterHead {
            facts.append(
                .init(
                    label: "HEAD",
                    value: afterHead
                )
            )
        }

        let observations: [AgentToolResultObservation] =
            result.output.isEmpty
                ? []
                : [
                    .init(
                        kind: .detail,
                        label: "git",
                        content: result.output
                    )
                ]

        return .init(
            projection: .init(
                status:
                    result.changed
                        ? "updated"
                        : "up to date",
                summary:
                    "\(result.currentBranch) <- \(result.remote)/\(result.upstreamBranch)",
                facts: facts
            ),
            observations: observations
        )
    }
}

private extension GitPullTool {
    struct PullContext:
        Sendable
    {
        let workspace: AgentWorkspace
        let state: GitManagerRepositoryState
        let remote: String
        let upstreamBranch: String
        let currentBranch: String
    }

    func resolvedContext(
        _ candidate: AgentWorkspace?
    ) async throws -> PullContext {
        let workspace =
            try AgenticGitToolSupport
                .requireWorkspace(
                    candidate,
                    toolName: name
                )

        try await AgenticGitToolSupport
            .requireRepositoryRoot(
                workspace,
                toolName: name
            )

        let state =
            try await GitManagerRepositoryInspector
                .state(
                    at: workspace.rootURL,
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
            workspace: workspace,
            state: state,
            remote: remote,
            upstreamBranch: upstreamBranch,
            currentBranch: currentBranch
        )
    }
}
