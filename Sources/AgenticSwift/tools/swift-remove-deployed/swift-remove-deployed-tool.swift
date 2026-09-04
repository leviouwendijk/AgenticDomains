import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Primitives
import Schema
import SchemaMacros

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


public struct SwiftRemoveDeployedToolOutput: Sendable, Codable, Hashable {
    public let product: String
    public let destination: String
    public let status: String

    public init(product: String, destination: String, status: String) {
        self.product = product
        self.destination = destination
        self.status = status
    }
}

public struct SwiftRemoveDeployedTool: AgentTool {
    public typealias Input = SwiftRemoveDeployedToolInput
    public typealias Output = SwiftRemoveDeployedToolOutput
    public static let identifier: AgentToolIdentifier = "swift_remove_deployed"
    public static let description =
        "Remove one deployed Swift binary and its metadata through Executable.Remove."
    public static let risk: ActionRisk = .privileged
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

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            context.workspace,
            toolName: name
        )
        let destination = Build.defaultDeploymentDirectory

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: workspace.rootURL.path,
            targetPaths: [
                destination.appendingPathComponent(
                    input.product
                ).path,
                destination.appendingPathComponent(
                    "\(input.product).metadata"
                ).path,
            ],
            summary: "Remove deployed Swift product '\(input.product)'.",
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
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        _ = try AgenticSwiftToolSupport.requireWorkspace(
            context.workspace,
            toolName: name
        )
        let destination = Build.defaultDeploymentDirectory

        try Remove.deployedBinary(
            named: input.product,
            at: destination
        )

        return SwiftRemoveDeployedToolOutput(
            product: input.product,
            destination: destination.path,
            status: "passed"
        )
    }
}
