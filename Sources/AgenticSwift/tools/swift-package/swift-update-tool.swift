import Agentic
import Macros
import Schema
import Workspace
import Executable
import Primitives

public struct SwiftUpdateTool: Tool {
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
        public let operation: String
        public let isSuccess: Bool
        public let exitCode: Int
        public let stdout: String
        public let stderr: String

        public init(
            operation: String,
            isSuccess: Bool,
            exitCode: Int,
            stdout: String,
            stderr: String
        ) {
            self.operation = operation
            self.isSuccess = isSuccess
            self.exitCode = exitCode
            self.stdout = stdout
            self.stderr = stderr
        }

        public var projection: ToolCall.ResultProjection {
            .init(
                status: isSuccess ? "passed" : "failed",
                summary: isSuccess
                    ? "Swift package \(operation) completed successfully."
                    : "Swift package \(operation) completed with a nonzero exit status.",
                facts: [
                    .init(label: "operation", value: operation),
                    .init(label: "exit", value: "\(exitCode)"),
                ]
            )
        }
    }

public static let identifier: ToolIdentifier =
        "swift_package_update"

    public static let description =
        """
        Run SwiftPM dependency update for the current workspace through Executable.Package.update.
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
