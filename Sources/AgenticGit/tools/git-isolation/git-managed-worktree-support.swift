import Foundation
import Interfaces

enum AgenticGitManagedWorktreeKind: String {
    case task = "tasks"
    case integration
}

enum AgenticGitManagedWorktrees {
    static func root(
        repository: URL,
        kind: AgenticGitManagedWorktreeKind
    ) throws -> URL {
        let repositoryID = try GitManagerIsolationID(
            repository.standardizedFileURL.path
        )

        return FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "agentic-git-worktrees",
                isDirectory: true
            )
            .appendingPathComponent(
                repositoryID.pathComponent,
                isDirectory: true
            )
            .appendingPathComponent(
                kind.rawValue,
                isDirectory: true
            )
            .standardizedFileURL
    }

    static func destination(
        repository: URL,
        isolationID: GitManagerIsolationID,
        kind: AgenticGitManagedWorktreeKind
    ) throws -> URL {
        try root(
            repository: repository,
            kind: kind
        )
        .appendingPathComponent(
            isolationID.pathComponent,
            isDirectory: true
        )
        .standardizedFileURL
    }

    static func ensureParent(
        for destination: URL
    ) throws {
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    static func requireManaged(
        _ path: String,
        repository: URL,
        kind: AgenticGitManagedWorktreeKind
    ) throws -> URL {
        try requireManaged(
            URL(
                fileURLWithPath: path,
                isDirectory: true
            ),
            repository: repository,
            kind: kind
        )
    }

    static func requireManaged(
        _ candidate: URL,
        repository: URL,
        kind: AgenticGitManagedWorktreeKind
    ) throws -> URL {
        let candidate = candidate.standardizedFileURL
        let root = try root(
            repository: repository,
            kind: kind
        )
        let prefix = root.path.hasSuffix("/")
            ? root.path
            : root.path + "/"

        guard candidate.path.hasPrefix(prefix) else {
            throw GitManagerError.unsafeSync(
                "Refusing unmanaged Agentic Git worktree path: \(candidate.path). Expected a descendant of \(root.path)."
            )
        }

        return candidate
    }
}
