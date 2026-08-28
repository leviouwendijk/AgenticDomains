import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Primitives

public struct SwiftBuildObjectModernizeToolInput:
    Sendable,
    Codable,
    Hashable
{
    public let backup: Bool?

    public init(
        backup: Bool? = nil
    ) {
        self.backup = backup
    }

    public static var schema: JSONValue {
        JSONSchema.object {
            JSONSchema.boolean(
                "backup",
                description: "Write build-object.pkl.bak before modernization. Defaults to true."
            )
        }
    }
}

public struct SwiftBuildObjectModernizeTool: StaticAgentTool {
    public static let identifier: AgentToolIdentifier = "swift_build_object_modernize"
    public static let description =
        "Modernize a legacy build-object.pkl through Executable.BuildObjectLifecycle."
    public static let risk: ActionRisk = .boundedmutate
    public static var inputSchema: JSONValue? {
        SwiftBuildObjectModernizeToolInput.schema
    }

    public init() {}

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        let decoded = try JSONToolBridge.decode(
            SwiftBuildObjectModernizeToolInput.self,
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
            targetPaths: decoded.backup == false
                ? ["build-object.pkl"]
                : ["build-object.pkl", "build-object.pkl.bak"],
            summary: "Modernize legacy Swift build-object configuration.",
            estimatedWriteCount: decoded.backup == false ? 1 : 2,
            policyChecks: [
                "workspace_required",
                "typed_build_object_modernization",
            ]
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            SwiftBuildObjectModernizeToolInput.self,
            from: input
        )
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )
        let result = try BuildObjectLifecycle.modernize(
            at: workspace.rootURL,
            backup: decoded.backup ?? true
        )

        var fields: [String: JSONValue] = [
            "path": .string(result.configurationURL.path),
            "name": .string(result.name),
            "modernized": .bool(result.modernized),
        ]

        if let backup = result.backupURL {
            fields["backup"] = .string(backup.path)
        }

        return .object(fields)
    }
}
