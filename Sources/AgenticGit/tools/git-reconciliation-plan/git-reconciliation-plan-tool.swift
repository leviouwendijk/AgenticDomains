import Agentic
import AgenticExecution
import AgenticWorkspace
import Interfaces
import Primitives
import Schema

public struct GitReconciliationPlanTool: StaticSchemaAgentTool {
    public typealias Input = AgenticGitEmptyToolInput
    public static let identifier: AgentToolIdentifier =
        "git_reconciliation_plan"

    public static let description =
        """
        Diagnose the current Agentic workspace Git repository and return the recommended reconciliation without fetching or applying Git changes.
        """

    public static let risk: ActionRisk = .observe

    public init() {}

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        _ = input

        let workspace = try AgenticGitToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )

        let result = try await GitManagerReconciler.reconcile(
            at: workspace.rootURL,
            fetch: false,
            apply: false,
            cleanUntracked: false
        )

        return try JSONToolBridge.encode(
            result
        )
    }
}
