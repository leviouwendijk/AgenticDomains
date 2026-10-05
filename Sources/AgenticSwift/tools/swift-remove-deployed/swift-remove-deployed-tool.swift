import Agentic
import Workspace
import Executable
import Primitives
import Schema
import Macros

public struct SwiftRemoveDeployedTool: Tool {
    @JSONSchema
    public struct Input:
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

    @JSONSchema
    public struct Output: Sendable, Codable, Hashable {
        public let product: String
        public let destination: String
        public let status: String

        public init(product: String, destination: String, status: String) {
            self.product = product
            self.destination = destination
            self.status = status
        }
    }

public static let identifier: ToolIdentifier = "swift_remove_deployed"
    public static let description =
        "Remove one deployed Swift binary and its metadata through Executable.Remove."
    public static let risk: ActionRisk = .privileged

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

    public func preflight(
        _ input: Input,
        in context: ToolContext
    ) async throws -> ToolPreflight {
        _ = try AgenticSwiftToolSupport.requireWorkspace(
            context.workspace,
            toolName: Self.definition.identifier.rawValue
        )
        let destination = Build.defaultDeploymentDirectory

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary: "Remove deployed Swift product '\(input.product)'.",
            access: .init(
                targets: [
                    destination.appendingPathComponent(
                        input.product
                    ).path,
                    destination.appendingPathComponent(
                        "\(input.product).metadata"
                    ).path,
                ]
            ),
            estimates: .init(
                write: .init(
                    count: 2
                )
            ),
            sideEffects: [
                "May remove a deployed executable and its metadata outside the workspace."
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
        in context: ToolContext
    ) async throws -> Output {
        _ = try AgenticSwiftToolSupport.requireWorkspace(
            context.workspace,
            toolName: Self.definition.identifier.rawValue
        )
        let destination = Build.defaultDeploymentDirectory

        try Remove.deployedBinary(
            named: input.product,
            at: destination
        )

        return Output(
            product: input.product,
            destination: destination.path,
            status: "passed"
        )
    }
}
