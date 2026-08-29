import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Primitives
import Schema

@JSONSchema
public struct SwiftBuildObjectInitToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Create minimal empty build-object/compiled files. Defaults to false.
    public let empty: Bool?

    /// Build object name. Defaults to workspace folder name.
    public let name: String?

    /// Executable object types. Defaults to [binary].
    public let types: [String]?

    /// Optional build-object details.
    public let details: String?

    /// Optional author. Defaults to current user.
    public let author: String?

    /// Optional update URL.
    public let update: String?

    /// Also create compiled.pkl when missing. Defaults to true.
    public let createCompiled: Bool?

    public init(
        empty: Bool? = nil,
        name: String? = nil,
        types: [String]? = nil,
        details: String? = nil,
        author: String? = nil,
        update: String? = nil,
        createCompiled: Bool? = nil
    ) {
        self.empty = empty
        self.name = name
        self.types = types
        self.details = details
        self.author = author
        self.update = update
        self.createCompiled = createCompiled
    }
}

public struct SwiftBuildObjectInitTool: StaticAgentTool {
    public static let identifier: AgentToolIdentifier = "swift_build_object_init"
    public static let description =
        "Initialize build-object.pkl and optionally compiled.pkl through Executable.BuildObjectLifecycle."
    public static let risk: ActionRisk = .boundedmutate
    public static var inputSchema: JSONValue? {
        SwiftBuildObjectInitToolInput.jsonschema.jsonvalue
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
            summary: "Initialize Swift build-object configuration.",
            estimatedWriteCount: 2,
            policyChecks: [
                "workspace_required",
                "typed_build_object_initialization",
            ]
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            SwiftBuildObjectInitToolInput.self,
            from: input
        )
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )

        let result: BuildObjectLifecycle.InitializeResult
        if decoded.empty == true {
            result = try BuildObjectLifecycle.initializeEmpty(
                at: workspace.rootURL
            )
        } else {
            result = try BuildObjectLifecycle.initialize(
                at: workspace.rootURL,
                request: .init(
                    name: decoded.name,
                    types: decoded.types ?? ["binary"],
                    details: decoded.details ?? "",
                    author: decoded.author,
                    update: decoded.update ?? "",
                    createCompiled: decoded.createCompiled ?? true
                )
            )
        }

        return .object([
            "configuration": .string(result.configurationURL.path),
            "compiled": .string(result.compiledURL.path),
            "createdConfiguration": .bool(result.createdConfiguration),
            "createdCompiled": .bool(result.createdCompiled),
        ])
    }
}
