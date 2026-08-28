import Agentic
import AgenticExecution
import AgenticWorkspace
import Interfaces
import Primitives

public struct GitDiffToolInput:
    Sendable,
    Codable,
    Hashable
{
    public let scope: GitManagerDiffScope
    public let paths: [String]
    public let contextLines: Int
    public let maxPatchBytes: Int

    public init(
        scope: GitManagerDiffScope = .both,
        paths: [String] = [],
        contextLines: Int = 3,
        maxPatchBytes: Int = 262_144
    ) {
        self.scope = scope
        self.paths = paths
        self.contextLines = contextLines
        self.maxPatchBytes = maxPatchBytes
    }

    private enum CodingKeys:
        String,
        CodingKey
    {
        case scope
        case paths
        case contextLines
        case maxPatchBytes
    }

    public init(
        from decoder: Decoder
    ) throws {
        let container =
            try decoder.container(
                keyedBy: CodingKeys.self
            )

        self.init(
            scope:
                try container.decodeIfPresent(
                    GitManagerDiffScope.self,
                    forKey: .scope
                ) ?? .both,
            paths:
                try container.decodeIfPresent(
                    [String].self,
                    forKey: .paths
                ) ?? [],
            contextLines:
                try container.decodeIfPresent(
                    Int.self,
                    forKey: .contextLines
                ) ?? 3,
            maxPatchBytes:
                try container.decodeIfPresent(
                    Int.self,
                    forKey: .maxPatchBytes
                ) ?? 262_144
        )
    }
}

public extension GitDiffToolInput {
    static var schema: JSONValue {
        JSONSchema.object(
            description:
                """
                Observe tracked Git differences for the current Agentic workspace repository.
                The workspace must be the Git repository root.
                No fetching or mutation is performed.
                Untracked file contents are not included.
                """
        ) {
            JSONSchema.string(
                "scope",
                description:
                    "Diff scope. Defaults to both.",
                cases:
                    GitManagerDiffScope
                        .allCases
                        .map(\.rawValue)
            )

            JSONSchema.array(
                "paths",
                description:
                    "Optional literal repository-relative paths to restrict the diff. Parent traversal and absolute paths are rejected.",
                items:
                    JSONSchema.Value.string()
            )

            JSONSchema.integer(
                "contextLines",
                description:
                    "Optional unified-diff context line count. Defaults to 3 and is clamped by Interfaces to 0...20."
            )

            JSONSchema.integer(
                "maxPatchBytes",
                description:
                    "Optional maximum returned patch bytes per diff section. Defaults to 262144 and is clamped by Interfaces to 1...1048576."
            )
        }
    }

    var request: GitManagerDiffRequest {
        .init(
            scope: scope,
            paths: paths,
            contextLines: contextLines,
            maxPatchBytes: maxPatchBytes
        )
    }
}

public struct GitDiffTool:
    StaticAgentTool
{
    public static let identifier:
        AgentToolIdentifier =
            "git_diff"

    public static let description =
        """
        Observe bounded tracked Git working-tree and staged patches for the current Agentic workspace repository.
        """

    public static let risk:
        ActionRisk =
            .observe

    public static var inputSchema:
        JSONValue?
    {
        GitDiffToolInput.schema
    }

    public init() {}

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        let decoded =
            try JSONToolBridge.decode(
                GitDiffToolInput.self,
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

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot:
                workspace.rootURL.path,
            targetPaths:
                decoded.paths,
            summary:
                "Observe \(decoded.scope.rawValue) tracked Git differences.",
            sideEffects: [],
            policyChecks: [
                "workspace_required",
                "repository_root_workspace",
                "typed_git_diff",
                "no_fetch",
                "no_mutation",
                "tracked_content_only",
            ]
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let decoded =
            try JSONToolBridge.decode(
                GitDiffToolInput.self,
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

        let result =
            try await GitManagerDiff
                .observe(
                    decoded.request,
                    at:
                        workspace.rootURL
                )

        return try JSONToolBridge
            .encode(
                result
            )
    }
}
