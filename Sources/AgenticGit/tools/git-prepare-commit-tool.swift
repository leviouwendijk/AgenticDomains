import Agentic
import Workspace
import Foundation
import Interfaces
import Primitives
import Schema
import Macros

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
        in workspace: WorkspaceContext
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

            _ = try workspace.authorize(
                path,
                capability: .write
            )
        }

        return normalized
    }
}

@JSONSchema
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

public extension Git.Tools {
    @Tool("git_prepare_commit")
    struct PrepareCommit {
    public typealias Input = GitPrepareCommitToolInput
    public typealias Output = GitPrepareCommitToolOutput
    public static let purpose =
        """
        Stage an explicitly reviewed set of paths in the current Agentic workspace Git repository without committing or pushing.
        """

    public static let risk:
        ActionRisk =
            .boundedmutate




    public init() {}
    }
}
