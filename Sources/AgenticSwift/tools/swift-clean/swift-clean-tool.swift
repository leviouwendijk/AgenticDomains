import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Primitives

public struct SwiftCleanTool: StaticAgentTool {
    public static let identifier: AgentToolIdentifier = "swift_clean"
    public static let description =
        "Clean the current SwiftPM workspace through Executable.Build.clean."
    public static let risk: ActionRisk = .privileged
    public static var inputSchema: JSONValue? {
        JSONSchema.object {}
    }

    public init() {}

    public func preflight(
        input _: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: workspace.rootURL.path,
            targetPaths: [
                ".build/",
            ],
            summary: "Clean SwiftPM build artifacts.",
            commandPreview: "swift package clean",
            estimatedWriteCount: 1,
            sideEffects: [
                "Removes SwiftPM build artifacts under .build.",
            ],
            policyChecks: [
                "workspace_required",
                "typed_swift_clean",
                "human_review_required",
            ]
        )
    }

    public func call(
        input _: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )

        try await Build.clean(
            at: workspace.rootURL
        )

        return .object([
            "status": .string("passed"),
        ])
    }
}
