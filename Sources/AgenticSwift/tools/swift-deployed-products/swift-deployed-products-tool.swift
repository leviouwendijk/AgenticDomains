import Agentic
import Executable
import Primitives

public struct SwiftDeployedProductsToolInput:
    Sendable,
    Codable,
    Hashable
{
    public let includeDetails: Bool?

    public init(
        includeDetails: Bool? = nil
    ) {
        self.includeDetails = includeDetails
    }

    public static var schema: JSONValue {
        JSONSchema.object {
            JSONSchema.boolean(
                "includeDetails",
                description: "Read deployment metadata sidecars. Defaults to true."
            )
        }
    }
}

public struct SwiftDeployedProductsToolOutput:
    Sendable,
    Codable,
    Hashable
{
    public struct Product:
        Sendable,
        Codable,
        Hashable
    {
        public let name: String
        public let path: String
        public let projectRoot: String?
        public let buildType: String?

        public init(
            name: String,
            path: String,
            projectRoot: String?,
            buildType: String?
        ) {
            self.name = name
            self.path = path
            self.projectRoot = projectRoot
            self.buildType = buildType
        }
    }

    public let destination: String
    public let products: [Product]

    public init(
        destination: String,
        products: [Product]
    ) {
        self.destination = destination
        self.products = products
    }
}

public struct SwiftDeployedProductsTool: StaticAgentTool {
    public static let identifier: AgentToolIdentifier = "swift_deployed_products"
    public static let description =
        "List deployed Swift binaries through Executable.DeployedList."
    public static let risk: ActionRisk = .observe
    public static var inputSchema: JSONValue? {
        SwiftDeployedProductsToolInput.schema
    }

    public init() {}

    public func preflight(
        input: JSONValue,
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
                Build.defaultDeploymentDirectory.path,
            ],
            summary: "List deployed Swift products.",
            sideEffects: [],
            policyChecks: [
                "workspace_required",
                "typed_deployed_product_listing",
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
            SwiftDeployedProductsToolInput.self,
            from: input
        )
        let products = try DeployedList.listBinaries(
            at: Build.defaultDeploymentDirectory,
            includeDetails: decoded.includeDetails ?? true
        )

        return try JSONToolBridge.encode(
            SwiftDeployedProductsToolOutput(
                destination: Build.defaultDeploymentDirectory.path,
                products: products.map {
                    .init(
                        name: $0.name,
                        path: $0.path.path,
                        projectRoot: $0.metadata?.projectRootPath,
                        buildType: $0.metadata?.buildType
                    )
                }
            )
        )
    }
}
