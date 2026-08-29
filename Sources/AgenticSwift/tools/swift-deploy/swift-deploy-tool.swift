import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Foundation
import Primitives
import Schema

@JSONSchema
public struct SwiftDeployToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Built Swift configuration to deploy. Defaults to debug.
    @Schema(required: false)
    public let configuration: SwiftBuildToolInput.Configuration

    /// Optional executable product names to deploy. Omit or pass an empty array to deploy every executable product.
    @Schema(required: false)
    public let products: [String]

    public init(
        configuration: SwiftBuildToolInput.Configuration = .debug,
        products: [String] = []
    ) {
        self.configuration = configuration
        self.products = products
    }
}

private extension SwiftDeployToolInput {
    enum CodingKeys:
        String,
        CodingKey
    {
        case configuration
        case products
    }
}

public extension SwiftDeployToolInput {
    init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        self.init(
            configuration: try container.decodeIfPresent(
                SwiftBuildToolInput.Configuration.self,
                forKey: .configuration
            ) ?? .debug,
            products: try container.decodeIfPresent(
                [String].self,
                forKey: .products
            ) ?? []
        )
    }
}

public struct SwiftDeployToolOutput:
    Sendable,
    Codable,
    Hashable
{
    public let configuration: String
    public let destination: String
    public let products: [String]

    public init(
        configuration: String,
        destination: String,
        products: [String]
    ) {
        self.configuration = configuration
        self.destination = destination
        self.products = products
    }
}

public struct SwiftDeployTool: StaticSchemaAgentTool {
    public typealias Input = SwiftDeployToolInput
    public static let identifier: AgentToolIdentifier =
        "swift_deploy"

    public static let description =
        """
        Deploy already-built Swift executable products to Executable's canonical deployment directory using Executable.Deploy.
        """

    public static let risk: ActionRisk = .privileged

    public init() {}

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        let decoded = try JSONToolBridge.decode(
            SwiftDeployToolInput.self,
            from: input
        )
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )
        let resolved = try await resolution(
            decoded,
            workspace: workspace
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: workspace.rootURL.path,
            targetPaths: [
                resolved.destination.path,
            ],
            summary: "Deploy Swift executable product(s): \(resolved.plan.selectedProductNames.joined(separator: ", ")).",
            commandPreview: "deploy \(decoded.configuration.rawValue) -> \(resolved.destination.path)",
            estimatedWriteCount: max(
                1,
                resolved.plan.selectedProductNames.count * 2
            ),
            estimatedRuntimeSeconds: 60,
            sideEffects: [
                "Moves built executable artifacts from .build into the deployment destination.",
                "Replaces existing deployed products when present.",
                "Writes per-product deployment metadata using Executable.Deploy.",
            ],
            policyChecks: [
                "workspace_required",
                "typed_swift_deploy",
                "executable_products_resolved",
                "shared_executable_deploy_mechanics",
                "human_review_required",
            ],
            warnings: [
                "The canonical Executable deployment directory is outside the attached Agentic workspace."
            ]
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            SwiftDeployToolInput.self,
            from: input
        )
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )
        let resolved = try await resolution(
            decoded,
            workspace: workspace
        )

        try Deploy.selected(
            from: workspace.rootURL,
            config: resolved.plan.request.config,
            to: resolved.destination,
            products: resolved.plan.selectedProductNames,
            perProductDestinations: resolved.plan.perProductDestinations
        )

        return try JSONToolBridge.encode(
            SwiftDeployToolOutput(
                configuration: decoded.configuration.rawValue,
                destination: resolved.destination.path,
                products: resolved.plan.selectedProductNames
            )
        )
    }

    public func processResult(
        input _: JSONValue,
        output: JSONValue,
        workspace _: AgentWorkspace?
    ) -> AgentToolResultProcessing {
        guard let result = try? JSONToolBridge.decode(
            SwiftDeployToolOutput.self,
            from: output
        ) else {
            return .none
        }

        return .init(
            projection: .init(
                status: "passed",
                summary: "Swift deployment completed successfully.",
                facts: [
                    .init(
                        label: "configuration",
                        value: result.configuration
                    ),
                    .init(
                        label: "destination",
                        value: result.destination
                    ),
                    .init(
                        label: "products",
                        value: result.products.joined(separator: ", ")
                    ),
                ]
            )
        )
    }
}

private extension SwiftDeployTool {
    struct Resolution {
        let destination: URL
        let plan: Build.Plan
    }

    func resolution(
        _ input: SwiftDeployToolInput,
        workspace: AgentWorkspace
    ) async throws -> Resolution {
        let mode: Build.Config.Mode = switch input.configuration {
        case .debug:
            .debug

        case .release:
            .release
        }

        let destination = Build.defaultDeploymentDirectory

        let request = Build.Request(
            project: workspace.rootURL,
            config: .init(
                mode: mode,
                updateBuiltOnSuccess: false
            ),
            destination: destination,
            deploy: true,
            selection: .init(
                products: Set(input.products)
            ),
            source: .direct(
                arguments: []
            )
        )

        return Resolution(
            destination: destination,
            plan: try await Build.resolve(
                request
            )
        )
    }

}
