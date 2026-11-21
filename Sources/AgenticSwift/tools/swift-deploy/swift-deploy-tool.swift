import Agentic
import Workspace
import Executable
import Foundation
import Primitives
import Schema
import Macros


private extension SwiftLang.Tools.Deploy.Input {
    enum CodingKeys:
        String,
        CodingKey
    {
        case configuration
        case products
    }
}

public extension SwiftLang.Tools.Deploy.Input {
    init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        self.init(
            configuration: try container.decodeIfPresent(
                SwiftLang.Tools.Build.Input.Configuration.self,
                forKey: .configuration
            ) ?? .debug,
            products: try container.decodeIfPresent(
                [String].self,
                forKey: .products
            ) ?? []
        )
    }
}


public extension SwiftLang.Tools {
    @DomainMember(SwiftLang.self)
    struct Deploy: Tool {
        @JSONSchema
        public struct Input:
            Sendable,
            Codable,
            Hashable
        {
            /// Built Swift configuration to deploy. Defaults to debug.
            @Schema(required: false)
            public let configuration: SwiftLang.Tools.Build.Input.Configuration

            /// Optional executable product names to deploy. Omit or pass an empty array to deploy every executable product.
            @Schema(required: false)
            public let products: [String]

            public init(
                configuration: SwiftLang.Tools.Build.Input.Configuration = .debug,
                products: [String] = []
            ) {
                self.configuration = configuration
                self.products = products
            }
        }

        @JSONSchema
        public struct Output:
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

    public static let identifier: ToolIdentifier =
            "swift_deploy"

        public static let description =
            """
            Deploy already-built Swift executable products to Executable's canonical deployment directory using Executable.Deploy.
            """

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

    }
}
