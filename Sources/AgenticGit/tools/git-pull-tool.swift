import Agentic
import AgenticExecution
import AgenticWorkspace
import Foundation
import Interfaces
import Primitives
import Schema
import SchemaMacros

/// Pull the configured upstream for the current repository.
/// This tool intentionally accepts no remote, branch, force, rebase, merge, or checkout parameters.
@JSONSchema
public struct GitPullToolInput:
    Sendable,
    Codable,
    Hashable
{
}


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
    AgentTool
{
    public typealias Input = GitPullToolInput
    public typealias Output = GitPullToolOutput
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
