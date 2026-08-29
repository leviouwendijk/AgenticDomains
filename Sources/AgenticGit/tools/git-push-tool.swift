import Agentic
import AgenticExecution
import AgenticWorkspace
import Foundation
import Interfaces
import Primitives
import Schema

/// Push committed Git history for the current Agentic workspace repository.
/// Omit both remote and branch to use the repository's configured/default upstream resolution.
/// Supply both remote and branch to approve an explicit push destination.
/// This tool never checks out or changes branches.
@JSONSchema
public struct GitPushToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Optional explicit Git remote name. Must be supplied together with branch.
    public let remote: String?

    /// Optional explicit local branch or HEAD to push. Must be supplied together with remote. This does not switch branches.
    public let branch: String?

    /// When an explicit remote and branch are supplied, whether to set that destination as upstream. Defaults to true.
    @Schema(required: false)
    public let setUpstream: Bool

    public init(
        remote: String? = nil,
        branch: String? = nil,
        setUpstream: Bool = true
    ) {
        self.remote = remote
        self.branch = branch
        self.setUpstream = setUpstream
    }
}

private extension GitPushToolInput {
    enum CodingKeys:
        String,
        CodingKey
    {
        case remote
        case branch
        case setUpstream
    }
}

public extension GitPushToolInput {
    init(
        from decoder: Decoder
    ) throws {
        let container =
            try decoder.container(
                keyedBy: CodingKeys.self
            )

        self.init(
            remote:
                try container.decodeIfPresent(
                    String.self,
                    forKey: .remote
                ),
            branch:
                try container.decodeIfPresent(
                    String.self,
                    forKey: .branch
                ),
            setUpstream:
                try container.decodeIfPresent(
                    Bool.self,
                    forKey: .setUpstream
                ) ?? true
        )
    }
}

public extension GitPushToolInput {


    func validatedTarget()
        throws -> (remote: String, branch: String)?
    {
        let remote = normalized(
            self.remote
        )

        let branch = normalized(
            self.branch
        )

        switch (remote, branch) {
        case (.none, .none):
            return nil

        case (.some, .none), (.none, .some):
            throw GitManagerError.unsafeSync(
                "git_push requires both remote and branch when selecting an explicit destination. Omit both to use the configured upstream."
            )

        case let (.some(remote), .some(branch)):
            guard validRemote(remote) else {
                throw GitManagerError.unsafeSync(
                    "Invalid explicit Git remote for git_push: \(remote)"
                )
            }

            guard validBranch(branch) else {
                throw GitManagerError.unsafeSync(
                    "Invalid explicit Git branch for git_push: \(branch)"
                )
            }

            return (
                remote: remote,
                branch: branch
            )
        }
    }
}

private extension GitPushToolInput {
    func normalized(
        _ value: String?
    ) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmed.isEmpty
            ? nil
            : trimmed
    }

    func validRemote(
        _ value: String
    ) -> Bool {
        guard !value.hasPrefix("-") else {
            return false
        }

        return value.allSatisfy {
            $0.isLetter
                || $0.isNumber
                || $0 == "."
                || $0 == "_"
                || $0 == "-"
        }
    }

    func validBranch(
        _ value: String
    ) -> Bool {
        guard !value.hasPrefix("-"),
              !value.contains(".."),
              !value.contains("@{"),
              !value.contains("//"),
              !value.hasSuffix("."),
              !value.hasSuffix("/")
        else {
            return false
        }

        return value.allSatisfy {
            $0.isLetter
                || $0.isNumber
                || $0 == "."
                || $0 == "_"
                || $0 == "-"
                || $0 == "/"
        }
    }
}

public struct GitPushToolOutput:
    Sendable,
    Codable,
    Hashable
{
    public let remote: String?
    public let branch: String?
    public let configuredTarget: String?
    public let currentBranch: String?
    public let setUpstream: Bool
    public let output: String

    public init(
        remote: String?,
        branch: String?,
        configuredTarget: String?,
        currentBranch: String?,
        setUpstream: Bool,
        output: String
    ) {
        self.remote = remote
        self.branch = branch
        self.configuredTarget = configuredTarget
        self.currentBranch = currentBranch
        self.setUpstream = setUpstream
        self.output = output
    }
}

public struct GitPushTool:
    StaticSchemaAgentTool
{
    public typealias Input = GitPushToolInput
    public static let identifier:
        AgentToolIdentifier =
            "git_push"

    public static let description =
        """
        Push committed Git history to the configured upstream or to an explicitly approved remote and branch without changing branches.
        """

    public static let risk:
        ActionRisk =
            .privileged

    public init() {}

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        let decoded =
            try JSONToolBridge.decode(
                GitPushToolInput.self,
                from: input
            )

        let target =
            try decoded.validatedTarget()

        let workspace =
            try AgenticGitToolSupport
                .requireWorkspace(
                    workspace,
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

        let destination: String

        if let target {
            destination =
                "\(target.remote)/\(target.branch)"
        } else {
            destination =
                state.upstreamDisplay
                    ?? "configured/default upstream"
        }

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot:
                workspace.rootURL.path,
            targetPaths: [],
            summary:
                "Push Git history from current branch \(state.branch ?? "unknown") to \(destination).",
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
                "repository_root_workspace",
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
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let decoded =
            try JSONToolBridge.decode(
                GitPushToolInput.self,
                from: input
            )

        let target =
            try decoded.validatedTarget()

        let workspace =
            try AgenticGitToolSupport
                .requireWorkspace(
                    workspace,
                    toolName: name
                )

        try await AgenticGitToolSupport
            .requireRepositoryRoot(
                workspace,
                toolName: name
            )

        let before =
            try await GitManagerRepositoryInspector
                .state(
                    at: workspace.rootURL,
                    fetch: false
                )

        let output: String

        if let target {
            output =
                try await GitManagerAction.push(
                    remote: target.remote,
                    branch: target.branch,
                    setUpstream:
                        decoded.setUpstream,
                    at: workspace.rootURL
                )
        } else {
            output =
                try await GitManagerAction.push(
                    at: workspace.rootURL
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
