import Agentic
import Executable
import Primitives

public struct SwiftRunProductToolInput:
    Sendable,
    Codable,
    Hashable
{
    public let product: String
    public let verbose: Bool

    public init(
        product: String,
        verbose: Bool = true
    ) {
        self.product = product
        self.verbose = verbose
    }

    private enum CodingKeys:
        String,
        CodingKey
    {
        case product
        case verbose
    }

    public init(
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

    public static var schema:
        JSONValue
    {
        JSONSchema.object {
            JSONSchema.string(
                "product",
                required: true,
                description:
                    "Exact executable SwiftPM product name returned by swift_executable_products."
            )

            JSONSchema.boolean(
                "verbose",
                description:
                    "When true, append the fixed --verbose argument. Intended for TestFlows and other products that support it. Defaults to true."
            )
        }
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
    StaticAgentTool
{
    public static let identifier:
        AgentToolIdentifier =
            "swift_run_product"

    public static let description =
        """
        Run one discovered executable SwiftPM product in the current workspace through Executable and Processes. The model cannot supply arbitrary process arguments.
        """

    public static let risk:
        ActionRisk = .privileged

    public static var inputSchema:
        JSONValue?
    {
        SwiftRunProductToolInput.schema
    }

    public init() {}

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        let decoded =
            try JSONToolBridge.decode(
                SwiftRunProductToolInput.self,
                from: input
            )

        let workspace =
            try AgenticSwiftToolSupport
                .requireWorkspace(
                    workspace,
                    toolName: name
                )

        let available:
            [ExecutableProduct]

        do {
            available =
                try await Products.executables(
                    in:
                        workspace.rootURL
                )
        } catch ProductsError
            .noExecutableProductsFound
        {
            available = []
        }

        let names =
            available
                .map(\.name)
                .sorted()

        guard names.contains(
            decoded.product
        ) else {
            throw SwiftRunError.productNotFound(
                product:
                    decoded.product,
                available:
                    names
            )
        }

        let suffix =
            decoded.verbose
            ? " --verbose"
            : ""

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot:
                workspace.rootURL.path,
            targetPaths: [
                ".build/",
            ],
            summary:
                "Run Swift executable product '\(decoded.product)'.",
            commandPreview:
                "swift run \(decoded.product)\(suffix)",
            estimatedWriteCount: 1,
            estimatedRuntimeSeconds: 300,
            sideEffects: [
                "May build the selected executable product under .build before execution.",
                "Executes repository-owned code with the current host filesystem, process, environment, and network permissions.",
                "Execution is managed by Processes with an output limit and timeout.",
            ],
            policyChecks: [
                "workspace_required",
                "executable_product_discovered",
                "no_model_supplied_process_arguments",
                "managed_process_execution",
                "human_review_required",
            ],
            warnings: [
                "Executed repository code is not confined by Agentic PathSandbox."
            ]
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let decoded =
            try JSONToolBridge.decode(
                SwiftRunProductToolInput.self,
                from: input
            )

        let workspace =
            try AgenticSwiftToolSupport
                .requireWorkspace(
                    workspace,
                    toolName: name
                )

        let arguments =
            decoded.verbose
            ? [
                "--verbose",
            ]
            : []

        let result =
            try await SwiftRun.run(
                .init(
                    product:
                        decoded.product,
                    arguments:
                        arguments
                ),
                at:
                    workspace.rootURL,
                options:
                    .init(
                        outputLimit:
                            4 * 1024 * 1024,
                        timeout:
                            .seconds(300)
                    )
            )

        return try JSONToolBridge.encode(
            SwiftRunProductToolOutput(
                product:
                    result.product,
                isSuccess:
                    result.isSuccess,
                exitCode:
                    result.exitCode,
                signal:
                    result.signal,
                stdout:
                    result.stdoutText,
                stderr:
                    result.stderrText
            )
        )
    }

    public func processResult(
        input _: JSONValue,
        output: JSONValue,
        workspace _: AgentWorkspace?
    ) -> AgentToolResultProcessing {
        guard let result =
            try? JSONToolBridge.decode(
                SwiftRunProductToolOutput.self,
                from: output
            )
        else {
            return .none
        }

        var facts: [AgentToolResultProjection.Fact] = [
            .init(
                label: "product",
                value: result.product
            )
        ]

        if let exitCode = result.exitCode {
            facts.append(
                .init(
                    label: "exit",
                    value: "\(exitCode)"
                )
            )
        }

        if let signal = result.signal {
            facts.append(
                .init(
                    label: "signal",
                    value: "\(signal)"
                )
            )
        }

        var observations: [AgentToolResultObservation] = []

        if !result.stdout.isEmpty {
            observations.append(
                .init(
                    kind: .standard_output,
                    label: "stdout",
                    content: result.stdout
                )
            )
        }

        if !result.stderr.isEmpty {
            observations.append(
                .init(
                    kind: .standard_error,
                    label: "stderr",
                    content: result.stderr
                )
            )
        }

        return .init(
            projection: .init(
                status:
                    result.isSuccess
                        ? "passed"
                        : "failed",
                summary:
                    result.isSuccess
                        ? "Swift product '\(result.product)' completed successfully."
                        : "Swift product '\(result.product)' completed unsuccessfully.",
                facts: facts
            ),
            observations: observations
        )
    }
}
