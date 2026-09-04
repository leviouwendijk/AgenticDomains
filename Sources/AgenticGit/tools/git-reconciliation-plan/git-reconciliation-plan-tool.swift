import Agentic
import AgenticExecution
import AgenticWorkspace
import Interfaces
import Primitives
import Schema

public struct GitReconciliationPlanTool: AgentTool {
    public typealias Input = AgenticGitEmptyToolInput
    public typealias Output = GitManagerReconciliationResult
    public static let identifier: AgentToolIdentifier =
        "git_reconciliation_plan"

    public static let description =
        """
        Diagnose the current Agentic workspace Git repository and return the recommended reconciliation without fetching or applying Git changes.
        """

    public static let risk: ActionRisk = .observe

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
