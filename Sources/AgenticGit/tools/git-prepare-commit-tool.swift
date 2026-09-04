import Agentic
import AgenticExecution
import AgenticWorkspace
import Foundation
import Interfaces
import Primitives
import Schema
import SchemaMacros

/// Stage an explicit set of repository-relative paths in the current Agentic workspace for a later commit.
/// This modifies only the Git index. It does not create a commit or push anything.
/// Pass ["."] explicitly when the intended scope is the whole repository.
@JSONSchema
public struct GitPrepareCommitToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Explicit repository-relative paths to stage. At least one path is required. Pass '.' explicitly to stage the whole repository.
    public let paths: [String]

    public init(
        paths: [String]
    ) {
        self.paths = paths
    }
}

public extension GitPrepareCommitToolInput {


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
    AgentTool
{
    public typealias Input = GitPrepareCommitToolInput
    public typealias Output = GitPrepareCommitToolOutput
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
