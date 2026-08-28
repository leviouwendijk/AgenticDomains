import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Primitives

public struct SwiftUpdateTool: StaticAgentTool {
    public static let identifier: AgentToolIdentifier =
        "swift_package_update"

    public static let description =
        """
        Run SwiftPM dependency update for the current workspace through Executable.Package.update.
        """

    public static let risk: ActionRisk = .privileged

    public init() {}

    public func preflight(
        input _: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: workspace.rootURL.path,
            targetPaths: [
                "Package.resolved",
                ".build/",
            ],
            summary: "Update Swift package dependencies.",
            commandPreview: "swift package update",
            estimatedWriteCount: 2,
            estimatedRuntimeSeconds: 300,
            sideEffects: [
                "May update Package.resolved.",
                "May fetch package dependencies over the network.",
                "May update SwiftPM state under .build.",
            ],
            policyChecks: [
                "workspace_required",
                "typed_swift_package_update",
                "human_review_required",
            ],
            warnings: [
                "SwiftPM dependency update is not confined by Agentic PathSandbox."
            ]
        )
    }

    public func call(
        input _: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )

        let result = try await Package.update(
            at: workspace.rootURL
        )

        guard result.exitCode == 0 else {
            throw AgenticSwiftToolError.operationFailed(
                toolName: name,
                operation: "swift package update",
                exitCode: Int(result.exitCode),
                signal: nil,
                detail: String(
                    String(
                        decoding: result.stderr,
                        as: UTF8.self
                    ).prefix(16_384)
                )
            )
        }

        return try JSONToolBridge.encode(
            SwiftPackageOperationToolOutput(
                operation: "update",
                isSuccess: result.exitCode == 0,
                exitCode: Int(result.exitCode),
                stdout: String(
                    decoding: result.stdout,
                    as: UTF8.self
                ),
                stderr: String(
                    decoding: result.stderr,
                    as: UTF8.self
                )
            )
        )
    }

    public func processResult(
        input _: JSONValue,
        output: JSONValue,
        workspace _: AgentWorkspace?
    ) -> AgentToolResultProcessing {
        guard let result = try? JSONToolBridge.decode(
            SwiftPackageOperationToolOutput.self,
            from: output
        ) else {
            return .none
        }

        return result.processing
    }
}
