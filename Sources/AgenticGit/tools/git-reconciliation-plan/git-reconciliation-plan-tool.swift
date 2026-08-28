import Agentic
import AgenticExecution
import AgenticWorkspace
import Interfaces
import Primitives

public struct GitReconciliationPlanTool: StaticAgentTool {
    public static let identifier: AgentToolIdentifier =
        "git_reconciliation_plan"

    public static let description =
        """
        Diagnose the current Agentic workspace Git repository and return the recommended reconciliation without fetching or applying Git changes.
        """

    public static let risk: ActionRisk = .observe

    public static var inputSchema: JSONValue? {
        JSONSchema.object {}
    }

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
