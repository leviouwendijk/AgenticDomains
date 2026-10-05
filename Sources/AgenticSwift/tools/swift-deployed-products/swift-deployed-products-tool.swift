import Agentic
import Workspace
import Executable
import Primitives
import Schema
import Macros

public struct SwiftDeployedProductsTool: Tool {
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        /// Read deployment metadata sidecars. Defaults to true.
        public let includeDetails: Bool?

        public init(
            includeDetails: Bool? = nil
        ) {
            self.includeDetails = includeDetails
        }
    }

    @JSONSchema
    public struct Output:
        Sendable,
        Codable,
        Hashable
    {
        @JSONSchema
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

public static let identifier: ToolIdentifier = "swift_deployed_products"
    public static let description =
        "List deployed Swift binaries through Executable.DeployedList."
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

    public func preflight(
        _ input: Input,
        in context: ToolContext
    ) async throws -> ToolPreflight {
        _ = try AgenticSwiftToolSupport.requireWorkspace(
            context.workspace,
            toolName: Self.definition.identifier.rawValue
        )
        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary: "List deployed Swift products.",
            access: .init(
                targets: [
                    Build.defaultDeploymentDirectory.path
                ]
            ),
            sideEffects: [],
            policyChecks: [
                "workspace_required",
                "typed_deployed_product_listing",
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
        let products = try DeployedList.listBinaries(
            at: Build.defaultDeploymentDirectory,
            includeDetails: input.includeDetails ?? true
        )

        return Output(
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
    }
}
