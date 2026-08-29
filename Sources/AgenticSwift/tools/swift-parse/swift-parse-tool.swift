import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Foundation
import Primitives
import Schema

@JSONSchema
public struct SwiftParseToolInput:
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

public struct SwiftParseToolOutput:
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

public struct SwiftParseTool: StaticAgentTool {
    public static let identifier: AgentToolIdentifier = "swift_parse"
    public static let description =
        "Parse one Swift source file with the compiler parser through Executable.SwiftCompiler."
    public static let risk: ActionRisk = .observe
    public static var inputSchema: JSONValue? {
        SwiftParseToolInput.jsonschema.jsonvalue
    }

    public init() {}

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        let decoded = try JSONToolBridge.decode(
            SwiftParseToolInput.self,
            from: input
        )
        let path = try AgenticSwiftToolSupport.resolvedPreflightPath(
            decoded.path,
            workspace: workspace
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: workspace?.rootURL.path,
            targetPaths: [
                path,
            ],
            summary: "Parse Swift syntax in \(path).",
            commandPreview: "swiftc -parse \(path)",
            sideEffects: [],
            policyChecks: [
                "workspace_required",
                "workspace_file_resolved",
                "compiler_parse_only",
            ]
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )
        let decoded = try JSONToolBridge.decode(
            SwiftParseToolInput.self,
            from: input
        )
        let path = try workspace.resolve(
            decoded.path,
            type: .file
        )
        let file = try workspace.absoluteURL(
            for: path,
            type: .file
        )
        let result = try await SwiftCompiler.parse(
            file,
            workingDirectory: workspace.rootURL
        )

        guard result.isSuccess else {
            throw AgenticSwiftToolError.operationFailed(
                toolName: name,
                operation: "parse Swift source '\(decoded.path)'",
                exitCode: result.exitCode.map(Int.init),
                signal: result.signal.map(Int.init),
                detail: result.stderrText.isEmpty
                    ? result.stdoutText
                    : result.stderrText
            )
        }

        return try JSONToolBridge.encode(
            SwiftParseToolOutput(
                path: path.presentingRelative(
                    filetype: true
                ),
                stdout: result.stdoutText,
                stderr: result.stderrText
            )
        )
    }
}
