import Agentic
import Executable
import Primitives

public struct SwiftExecutableProductsToolOutput:
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
        public let targets: [String]

        public init(
            name: String,
            targets: [String]
        ) {
            self.name = name
            self.targets = targets
        }
    }

    public let products: [Product]

    public init(
        products: [Product]
    ) {
        self.products = products
    }
}

public struct SwiftExecutableProductsTool:
    StaticAgentTool
{
    public static let identifier:
        AgentToolIdentifier =
            "swift_executable_products"

    public static let description =
        """
        Discover executable SwiftPM products declared by the current Agentic workspace package.
        """

    public static let risk:
        ActionRisk = .observe

    public static var inputSchema:
        JSONValue?
    {
        JSONSchema.object {}
    }

    public init() {}

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        _ = input

        let workspace =
            try AgenticSwiftToolSupport
                .requireWorkspace(
                    workspace,
                    toolName: name
                )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot:
                workspace.rootURL.path,
            summary:
                "Discover executable SwiftPM products in the current workspace.",
            commandPreview:
                "swift package dump-package",
            sideEffects: [],
            policyChecks: [
                "workspace_required",
                "swift_package_introspection",
            ]
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        _ = input

        let workspace =
            try AgenticSwiftToolSupport
                .requireWorkspace(
                    workspace,
                    toolName: name
                )

        let discovered:
            [ExecutableProduct]

        do {
            discovered =
                try await Products.executables(
                    in: workspace.rootURL
                )
        } catch ProductsError
            .noExecutableProductsFound
        {
            discovered = []
        }

        let output =
            SwiftExecutableProductsToolOutput(
                products:
                    discovered
                        .sorted {
                            $0.name < $1.name
                        }
                        .map {
                            .init(
                                name: $0.name,
                                targets:
                                    $0.targets.sorted()
                            )
                        }
            )

        return try JSONToolBridge.encode(
            output
        )
    }
}
