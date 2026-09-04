import Agentic
import AgenticExecution
import Primitives

public struct SwiftPackageOperationToolOutput:
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

    public var projection: AgentToolResultProjection {
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

    public func observe(
        in context: AgentToolExecutionContext
    ) async {
        if !stdout.isEmpty {
            await context.observe(
                .init(kind: .standard_output, label: "stdout", content: stdout)
            )
        }

        if !stderr.isEmpty {
            await context.observe(
                .init(kind: .standard_error, label: "stderr", content: stderr)
            )
        }
    }
}
