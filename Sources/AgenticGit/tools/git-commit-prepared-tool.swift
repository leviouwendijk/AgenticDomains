import Agentic
import Workspace
import Foundation
import Interfaces
import Primitives
import Schema
import Macros

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

@JSONSchema
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

public extension Git.Tools {
    @Tool("git_commit_prepared")
    struct CommitPrepared {
    public typealias Input = GitCommitPreparedToolInput
    public typealias Output = GitCommitPreparedToolOutput
    public static let purpose =
        """
        Create a local Git commit from the exact currently staged index without staging more paths or pushing.
        """

    public static let risk:
        ActionRisk =
            .privileged




    public init() {}
    }
}

private extension Git.Tools.CommitPrepared {
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
