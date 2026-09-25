import Agentic
import AgenticExecution
import Workspace
import Executable
import Primitives
import Schema
import Macros


public struct SwiftExecutableProductsTool:
    Tool
{
    @JSONSchema
    public struct Input:
        Codable,
        Sendable
    {
        public init() {}
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

public static let identifier:
        ToolIdentifier =
            "swift_executable_products"

    public static let description =
        """
        Discover executable SwiftPM products declared by the current Agentic workspace package.
        """

    public static let risk:
        ActionRisk = .observe

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


}
