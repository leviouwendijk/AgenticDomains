import Agentic
import AgenticExecution
import AgenticWorkspace
import Foundation
import Interfaces
import Primitives
import Schema
import SchemaMacros

/// Create one local Git commit from the already-prepared staged index.
/// This tool does not stage additional paths and does not push.
@JSONSchema
public struct GitCommitPreparedToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Commit message for the exact currently staged changes.
    public let message: String

    public init(
        message: String
    ) {
        self.message = message
    }
}

public extension GitCommitPreparedToolInput {


    func validatedMessage() throws -> String {
        let normalized = message.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !normalized.isEmpty else {
            throw GitManagerError.missingCommitMessage
        }

        return normalized
    }
}

public struct GitCommitPreparedToolOutput:
    Sendable,
    Codable,
    Hashable
{
    public let message: String
    public let branch: String?
    public let committedPaths: [String]
    public let output: String

    public init(
        message: String,
        branch: String?,
        committedPaths: [String],
        output: String
    ) {
        self.message = message
        self.branch = branch
        self.committedPaths = committedPaths
        self.output = output
    }
}

public struct GitCommitPreparedTool:
    TypedAgentTool
{
    public typealias Input = GitCommitPreparedToolInput
    public static let identifier:
        AgentToolIdentifier =
            "git_commit_prepared"

    public static let description =
        """
        Create a local Git commit from the exact currently staged index without staging more paths or pushing.
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
                GitCommitPreparedToolInput.self,
                from: input
            )

        let message =
            try decoded.validatedMessage()

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

        let paths = try await stagedPaths(
            at: workspace.rootURL
        )

        guard !paths.isEmpty else {
            throw GitManagerError.unsafeSync(
                "git_commit_prepared requires staged changes. Run git_prepare_commit first."
            )
        }

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot:
                workspace.rootURL.path,
            targetPaths: paths,
            summary:
                "Create a local commit from \(paths.count) staged path(s) with message: \(message)",
            sideEffects: [
                "create a Git commit from the current staged index",
                "does not stage additional paths",
                "does not push to a remote",
            ],
            policyChecks: [
                "workspace_required",
                "repository_root_workspace",
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
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let decoded =
            try JSONToolBridge.decode(
                GitCommitPreparedToolInput.self,
                from: input
            )

        let message =
            try decoded.validatedMessage()

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

        let paths = try await stagedPaths(
            at: workspace.rootURL
        )

        guard !paths.isEmpty else {
            throw GitManagerError.unsafeSync(
                "git_commit_prepared requires staged changes. Run git_prepare_commit first."
            )
        }

        let output =
            try await GitManagerAction
                .commitPrepared(
                    message: message,
                    at: workspace.rootURL
                )

        let state =
            try await GitManagerRepositoryInspector
                .state(
                    at: workspace.rootURL,
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

    public func processResult(
        input _: JSONValue,
        output: JSONValue,
        workspace _: AgentWorkspace?
    ) -> AgentToolResultProcessing {
        guard let result = try? JSONToolBridge.decode(
            GitCommitPreparedToolOutput.self,
            from: output
        ) else {
            return .none
        }

        return .init(
            projection: .init(
                status: "passed",
                summary:
                    "Created local Git commit: \(result.message)",
                facts: [
                    .init(
                        label: "message",
                        value: result.message
                    ),
                    .init(
                        label: "branch",
                        value: result.branch ?? "unknown"
                    ),
                    .init(
                        label: "paths",
                        value: result.committedPaths.joined(
                            separator: ", "
                        )
                    ),
                ]
            )
        )
    }
}

private extension GitCommitPreparedTool {
    func stagedPaths(
        at root: URL
    ) async throws -> [String] {
        let staged =
            try await GitManagerDiff.observe(
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
