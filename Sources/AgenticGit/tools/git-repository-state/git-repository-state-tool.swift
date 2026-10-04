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
            Inspect read-only Git repository status and state for the current Agentic workspace, including branch, working-tree changes, and untracked files, without fetching or mutating the repository.
            """

        public static let risk: ActionRisk = .observe

        public init() {}
    }
}
