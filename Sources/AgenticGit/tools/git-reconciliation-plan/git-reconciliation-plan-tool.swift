import Agentic
import Workspace
import Interfaces
import Primitives
import Schema
import Macros

public extension Git.Tools {
    @Tool("git_reconciliation_plan")
    struct ReconciliationPlan {
        public typealias Input = AgenticGitEmptyToolInput
        public typealias Output = GitManagerReconciliationResult

        public static let purpose =
            """
            Diagnose the current Agentic workspace Git repository and return the recommended reconciliation without fetching or applying Git changes.
            """

        public static let risk: ActionRisk = .observe

        public init() {}
    }
}
