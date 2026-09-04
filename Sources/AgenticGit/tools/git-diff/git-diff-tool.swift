import Agentic
import AgenticExecution
import AgenticWorkspace
import Interfaces
import Primitives
import Schema
import SchemaMacros

/// Observe tracked Git differences for the current Agentic workspace repository.
/// The workspace must be the Git repository root.
/// No fetching or mutation is performed.
/// Untracked file contents are not included.
@JSONSchema
public struct GitDiffToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Diff scope. Defaults to both.
    @Schema(required: false)
    public let scope: GitManagerDiffScope

    /// Optional literal repository-relative paths to restrict the diff. Parent traversal and absolute paths are rejected.
    @Schema(required: false)
    public let paths: [String]

    /// Optional unified-diff context line count. Defaults to 3 and is clamped by Interfaces to 0...20.
    @Schema(required: false)
    public let contextLines: Int

    /// Optional maximum returned patch bytes per diff section. Defaults to 262144 and is clamped by Interfaces to 1...1048576.
    @Schema(required: false)
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
}

private extension GitDiffToolInput {
    enum CodingKeys:
        String,
        CodingKey
    {
        case scope
        case paths
        case contextLines
        case maxPatchBytes
    }
}

public extension GitDiffToolInput {
    init(
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
    AgentTool
{
    public typealias Input = GitDiffToolInput
    public typealias Output = GitManagerDiffResult
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
