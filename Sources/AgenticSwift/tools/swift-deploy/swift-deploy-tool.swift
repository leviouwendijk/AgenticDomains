import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Foundation
import Primitives
import Schema
import SchemaMacros

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

public struct SwiftDeployTool: AgentTool {
    public typealias Input = SwiftDeployToolInput
    public typealias Output = SwiftDeployToolOutput
    public static let identifier: AgentToolIdentifier =
        "swift_deploy"

    public static let description =
        """
        Deploy already-built Swift executable products to Executable's canonical deployment directory using Executable.Deploy.
        """

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
