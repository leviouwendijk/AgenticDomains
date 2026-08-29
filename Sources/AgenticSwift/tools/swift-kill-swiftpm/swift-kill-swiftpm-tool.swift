import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Primitives
import Schema

@JSONSchema
public struct SwiftKillSwiftPMToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Use SIGKILL immediately. Defaults to false.
    public let force: Bool?

    /// Only list processes that would be terminated. Defaults to false.
    public let dryRun: Bool?

    public init(
        force: Bool? = nil,
        dryRun: Bool? = nil
    ) {
        self.force = force
        self.dryRun = dryRun
    }
}

public struct SwiftKillSwiftPMTool: TypedAgentTool {
    public typealias Input = SwiftKillSwiftPMToolInput
    public static let identifier: AgentToolIdentifier = "swift_kill_swiftpm"
    public static let description =
        "Inspect and terminate Swift/SwiftPM process trees through Executable.SwiftPMProcesses."
    public static let risk: ActionRisk = .privileged
    public init() {}

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        let decoded = try JSONToolBridge.decode(
            SwiftKillSwiftPMToolInput.self,
            from: input
        )
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: workspace.rootURL.path,
            summary: decoded.dryRun == true
                ? "Inspect SwiftPM processes without signaling them."
                : "Terminate detected SwiftPM process trees.",
            commandPreview: decoded.dryRun == true
                ? "kill-swiftpm --dry-run"
                : "kill-swiftpm",
            sideEffects: decoded.dryRun == true
                ? []
                : [
                    "Sends termination signals to detected Swift/SwiftPM process trees.",
                ],
            policyChecks: [
                "workspace_required",
                "typed_swiftpm_process_management",
                "human_review_required",
            ]
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            SwiftKillSwiftPMToolInput.self,
            from: input
        )
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )
        let processes = try await SwiftPMProcesses().killAll(
            force: decoded.force ?? false,
            dryRun: decoded.dryRun ?? false,
            cwd: workspace.rootURL
        )

        return .object([
            "count": .string(String(processes.count)),
            "dryRun": .bool(decoded.dryRun ?? false),
            "processes": .array(
                processes.map {
                    .object([
                        "pid": .string(String($0.pid)),
                        "command": .string($0.commandLine),
                    ])
                }
            ),
        ])
    }
}
