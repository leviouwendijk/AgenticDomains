import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Primitives
import Schema
import SchemaMacros

@JSONSchema
public struct SwiftRunProductToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Exact executable SwiftPM product name returned by swift_executable_products.
    public let product: String

    /// When true, append the fixed --verbose argument. Intended for TestFlows and other products that support it. Defaults to true.
    @Schema(required: false)
    public let verbose: Bool

    public init(
        product: String,
        verbose: Bool = true
    ) {
        self.product = product
        self.verbose = verbose
    }
}

private extension SwiftRunProductToolInput {
    enum CodingKeys:
        String,
        CodingKey
    {
        case product
        case verbose
    }
}

public extension SwiftRunProductToolInput {
    init(
        from decoder: Decoder
    ) throws {
        let container =
            try decoder.container(
                keyedBy:
                    CodingKeys.self
            )

        self.init(
            product:
                try container.decode(
                    String.self,
                    forKey:
                        .product
                ),
            verbose:
                try container
                    .decodeIfPresent(
                        Bool.self,
                        forKey:
                            .verbose
                    )
                    ?? true
        )
    }
}

public struct SwiftRunProductToolOutput:
    Sendable,
    Codable,
    Hashable
{
    public let product: String
    public let isSuccess: Bool
    public let exitCode: Int32?
    public let signal: Int32?
    public let stdout: String
    public let stderr: String

    public init(
        product: String,
        isSuccess: Bool,
        exitCode: Int32?,
        signal: Int32?,
        stdout: String,
        stderr: String
    ) {
        self.product = product
        self.isSuccess = isSuccess
        self.exitCode = exitCode
        self.signal = signal
        self.stdout = stdout
        self.stderr = stderr
    }
}

public struct SwiftRunProductTool:
    AgentTool
{
    public typealias Input = SwiftRunProductToolInput
    public typealias Output = SwiftRunProductToolOutput
    public static let identifier:
        AgentToolIdentifier =
            "swift_run_product"

    public static let description =
        """
        Run one discovered executable SwiftPM product in the current workspace through Executable and Processes. The model cannot supply arbitrary process arguments.
        """

    public static let risk:
        ActionRisk = .privileged

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
