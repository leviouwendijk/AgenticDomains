import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Primitives
import Schema

@JSONSchema
public struct SwiftRemoveDeployedToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Deployed product name to remove.
    public let product: String

    public init(
        product: String
    ) {
        self.product = product
    }
}

public struct SwiftRemoveDeployedTool: TypedAgentTool {
    public typealias Input = SwiftRemoveDeployedToolInput
    public static let identifier: AgentToolIdentifier = "swift_remove_deployed"
    public static let description =
        "Remove one deployed Swift binary and its metadata through Executable.Remove."
    public static let risk: ActionRisk = .privileged
    public init() {}

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )
        let decoded = try JSONToolBridge.decode(
            SwiftRemoveDeployedToolInput.self,
            from: input
        )
        let destination = Build.defaultDeploymentDirectory

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: workspace.rootURL.path,
            targetPaths: [
                destination.appendingPathComponent(
                    decoded.product
                ).path,
                destination.appendingPathComponent(
                    "\(decoded.product).metadata"
                ).path,
            ],
            summary: "Remove deployed Swift product '\(decoded.product)'.",
            estimatedWriteCount: 2,
            sideEffects: [
                "May remove a deployed executable and its metadata outside the workspace.",
            ],
            policyChecks: [
                "workspace_required",
                "typed_deployed_product_removal",
                "human_review_required",
            ]
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        _ = try AgenticSwiftToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )
        let decoded = try JSONToolBridge.decode(
            SwiftRemoveDeployedToolInput.self,
            from: input
        )
        let destination = Build.defaultDeploymentDirectory

        try Remove.deployedBinary(
            named: decoded.product,
            at: destination
        )

        return .object([
            "product": .string(decoded.product),
            "destination": .string(destination.path),
            "status": .string("passed"),
        ])
    }
}
