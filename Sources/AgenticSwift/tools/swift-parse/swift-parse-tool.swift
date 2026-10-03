import Agentic
import Workspace
import Executable
import Foundation
import Primitives
import Schema
import Macros

public struct SwiftParseTool: Tool {
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        /// Workspace-relative Swift source file to parse with swiftc -parse.
        public let path: String

        public init(
            path: String
        ) {
            self.path = path
        }
    }

    @JSONSchema
    public struct Output:
        Sendable,
        Codable,
        Hashable
    {
        public let path: String
        public let stdout: String
        public let stderr: String

        public init(
            path: String,
            stdout: String,
            stderr: String
        ) {
            self.path = path
            self.stdout = stdout
            self.stderr = stderr
        }
    }

public static let identifier: ToolIdentifier = "swift_parse"
    public static let description =
        "Parse one Swift source file with the compiler parser through Executable.SwiftCompiler."
    public static let risk: ActionRisk = .observe

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

    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        let path = try AgenticSwiftToolSupport.resolvedPreflightPath(
            input.path,
            workspace: context
        )

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary: "Parse Swift syntax in \(path).",
            access: .init(
                targets: [
                    path
                ]
            ),
            preview: .init(
                command: "swiftc -parse \(path)"
            ),
            sideEffects: [],
            policyChecks: [
                "workspace_required",
                "workspace_file_resolved",
                "compiler_parse_only",
            ]
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let file = try AgenticSwiftToolSupport.projectFileURL(
            input.path,
            workspace: workspace,
            toolName: Self.definition.identifier.rawValue
        )
        let result = try await SwiftCompiler.parse(
            file,
            workingDirectory: workspace.absoluteURL
        )

        guard result.isSuccess else {
            throw AgenticSwiftToolError.operationFailed(
                toolName: Self.definition.identifier.rawValue,
                operation: "parse Swift source '\(input.path)'",
                exitCode: result.exitCode.map(Int.init),
                signal: result.signal.map(Int.init),
                detail: result.stderrText.isEmpty
                    ? result.stdoutText
                    : result.stderrText
            )
        }

        return Output(
            path: input.path,
            stdout: result.stdoutText,
            stderr: result.stderrText
        )
    }
}
