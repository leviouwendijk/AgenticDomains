import Agentic
import Workspace
import Interfaces
import Primitives
import Schema

public struct GitReconciliationPlanTool: Tool {
    public typealias Input = AgenticGitEmptyToolInput
    public typealias Output = GitManagerReconciliationResult
    public static let identifier: ToolIdentifier =
        "git_reconciliation_plan"

    public static let description =
        """
        Diagnose the current Agentic workspace Git repository and return the recommended reconciliation without fetching or applying Git changes.
        """

    public static let risk: ActionRisk = .observe

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier {
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
