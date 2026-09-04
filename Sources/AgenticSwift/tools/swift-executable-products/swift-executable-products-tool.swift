import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Primitives
import Schema

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
    AgentTool
{
    public typealias Input = AgenticSwiftEmptyToolInput
    public typealias Output = SwiftExecutableProductsToolOutput
    public static let identifier:
        AgentToolIdentifier =
            "swift_executable_products"

    public static let description =
        """
        Discover executable SwiftPM products declared by the current Agentic workspace package.
        """

    public static let risk:
        ActionRisk = .observe

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


}
