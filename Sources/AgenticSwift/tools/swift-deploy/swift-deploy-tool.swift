import Agentic
import AgenticExecution
import Workspace
import Executable
import Foundation
import Primitives
import Schema
import Macros


private extension SwiftDeployTool.Input {
    enum CodingKeys:
        String,
        CodingKey
    {
        case configuration
        case products
    }
}

public extension SwiftDeployTool.Input {
    init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        self.init(
            configuration: try container.decodeIfPresent(
                SwiftBuildTool.Input.Configuration.self,
                forKey: .configuration
            ) ?? .debug,
            products: try container.decodeIfPresent(
                [String].self,
                forKey: .products
            ) ?? []
        )
    }
}


public struct SwiftDeployTool: Tool {
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        /// Built Swift configuration to deploy. Defaults to debug.
        @Schema(required: false)
        public let configuration: SwiftBuildTool.Input.Configuration

        /// Optional executable product names to deploy. Omit or pass an empty array to deploy every executable product.
        @Schema(required: false)
        public let products: [String]

        public init(
            configuration: SwiftBuildTool.Input.Configuration = .debug,
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

private extension SwiftDeployTool {
    struct Resolution {
        let destination: URL
        let plan: Build.Plan
    }

    func resolution(
        _ input: SwiftDeployTool.Input,
        workspace: WorkspaceContext
    ) async throws -> Resolution {
        let mode: Build.Config.Mode = switch input.configuration {
        case .debug:
            .debug

        case .release:
            .release
        }

        let destination = Build.defaultDeploymentDirectory

        let request = Build.Request(
            project: workspace.absoluteURL,
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
