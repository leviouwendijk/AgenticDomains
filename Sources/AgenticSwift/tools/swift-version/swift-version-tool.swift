import Agentic
import Executable
import Primitives
import Version

public struct SwiftVersionToolOutput:
    Sendable,
    Codable,
    Hashable
{
    public let name: String
    public let types: [String]
    public let compiled: String
    public let release: String
    public let ahead: Int?
    public let behind: Int?

    public init(
        name: String,
        types: [String],
        compiled: String,
        release: String,
        ahead: Int?,
        behind: Int?
    ) {
        self.name = name
        self.types = types
        self.compiled = compiled
        self.release = release
        self.ahead = ahead
        self.behind = behind
    }
}

public struct SwiftVersionTool: StaticAgentTool {
    public static let identifier: AgentToolIdentifier = "swift_version"
    public static let description =
        "Inspect build-object and compiled Swift project versions through Executable."
    public static let risk: ActionRisk = .observe
    public static var inputSchema: JSONValue? {
        JSONSchema.object {}
    }

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
                "build-object.pkl",
                "compiled.pkl",
            ],
            summary: "Inspect Swift project version state.",
            sideEffects: [],
            policyChecks: [
                "workspace_required",
                "typed_executable_version_inspection",
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
        let snapshot = try await ExecutableVersion.inspect(
            at: workspace.rootURL
        )

        return try JSONToolBridge.encode(
            SwiftVersionToolOutput(
                name: snapshot.name,
                types: snapshot.types,
                compiled: snapshot.compiled.string(
                    prefixStyle: .short,
                    prefixSpace: false
                ),
                release: snapshot.release.string(
                    prefixStyle: .short,
                    prefixSpace: false
                ),
                ahead: snapshot.ahead,
                behind: snapshot.behind
            )
        )
    }
}
