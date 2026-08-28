import Agentic
import AgenticExecution
import AgenticWorkspace
import Foundation
import Interfaces
import Primitives

public struct GitPrepareCommitToolInput:
    Sendable,
    Codable,
    Hashable
{
    public let paths: [String]

    public init(
        paths: [String]
    ) {
        self.paths = paths
    }
}

public extension GitPrepareCommitToolInput {
    static var schema: JSONValue {
        JSONSchema.object(
            description:
                """
                Stage an explicit set of repository-relative paths in the current Agentic workspace for a later commit.
                This modifies only the Git index. It does not create a commit or push anything.
                Pass [\".\"] explicitly when the intended scope is the whole repository.
                """
        ) {
            JSONSchema.array(
                "paths",
                required: true,
                description:
                    "Explicit repository-relative paths to stage. At least one path is required. Pass '.' explicitly to stage the whole repository.",
                items:
                    JSONSchema.Value.string()
            )
        }
    }

    func validatedPaths(
        in workspace: AgentWorkspace
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

        for path in normalized {
            _ = try workspace.resolve(
                path
            )
        }

        return normalized
    }
}

public struct GitPrepareCommitToolOutput:
    Sendable,
    Codable,
    Hashable
{
    public let requestedPaths: [String]
    public let stagedPaths: [String]
    public let output: String

    public init(
        requestedPaths: [String],
        stagedPaths: [String],
        output: String
    ) {
        self.requestedPaths = requestedPaths
        self.stagedPaths = stagedPaths
        self.output = output
    }
}

public struct GitPrepareCommitTool:
    StaticAgentTool
{
    public static let identifier:
        AgentToolIdentifier =
            "git_prepare_commit"

    public static let description =
        """
        Stage an explicitly reviewed set of paths in the current Agentic workspace Git repository without committing or pushing.
        """

    public static let risk:
        ActionRisk =
            .boundedmutate

    public static var inputSchema:
        JSONValue?
    {
        GitPrepareCommitToolInput.schema
    }

    public init() {}

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        let decoded =
            try JSONToolBridge.decode(
                GitPrepareCommitToolInput.self,
                from: input
            )

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

        let paths = try decoded.validatedPaths(
            in: workspace
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot:
                workspace.rootURL.path,
            targetPaths: paths,
            summary:
                "Stage \(paths.count) explicit repository path(s) for a later commit.",
            sideEffects: [
                "modify the Git index",
                "does not create a commit",
                "does not push to a remote",
            ],
            policyChecks: [
                "workspace_required",
                "repository_root_workspace",
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
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let decoded =
            try JSONToolBridge.decode(
                GitPrepareCommitToolInput.self,
                from: input
            )

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

        let paths = try decoded.validatedPaths(
            in: workspace
        )

        let output =
            try await GitManagerAction
                .prepareCommit(
                    paths: paths,
                    at: workspace.rootURL
                )

        let staged =
            try await GitManagerDiff.observe(
                .init(
                    scope: .staged
                ),
                at: workspace.rootURL
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
