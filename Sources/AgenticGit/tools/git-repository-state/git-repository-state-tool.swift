import Agentic
import Workspace
import Interfaces
import Primitives
import Schema
import Macros

public extension Git.Tools {
    @Tool("git_repository_state")
    struct RepositoryState {
        public typealias Input = AgenticGitEmptyToolInput
        public typealias Output = GitManagerRepositoryState

        public static let purpose =
            """
            Inspect Git branch, working-tree changes, and untracked files without fetching or mutation.
            Pass empty arguments: {}. To select a repository beneath the session workspace root, put execution.workspace.subpath beside arguments, not inside it.
            Example for a workspace rooted at swiftlibs: {"arguments": {}, "execution": {"workspace": {"subpath": "Agentic"}}}. The selected directory must be the Git repository root, not a directory inside it. Omit execution only when the session workspace is already the repository root.
            """

        public static let risk: ActionRisk = .observe

        public init() {}
    }
}
