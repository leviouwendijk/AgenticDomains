import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Primitives

public struct SwiftBuildObjectInitToolInput:
    Sendable,
    Codable,
    Hashable
{
    public let empty: Bool?
    public let name: String?
    public let types: [String]?
    public let details: String?
    public let author: String?
    public let update: String?
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

    public static var schema: JSONValue {
        JSONSchema.object {
            JSONSchema.boolean(
                "empty",
                description: "Create minimal empty build-object/compiled files. Defaults to false."
            )
            JSONSchema.string(
                "name",
                description: "Build object name. Defaults to workspace folder name."
            )
            JSONSchema.array(
                "types",
                description: "Executable object types. Defaults to [binary].",
                items: JSONSchema.Value.string()
            )
            JSONSchema.string(
                "details",
                description: "Optional build-object details."
            )
            JSONSchema.string(
                "author",
                description: "Optional author. Defaults to current user."
            )
            JSONSchema.string(
                "update",
                description: "Optional update URL."
            )
            JSONSchema.boolean(
                "createCompiled",
                description: "Also create compiled.pkl when missing. Defaults to true."
            )
        }
    }
}

public struct SwiftBuildObjectInitTool: StaticAgentTool {
    public static let identifier: AgentToolIdentifier = "swift_build_object_init"
    public static let description =
        "Initialize build-object.pkl and optionally compiled.pkl through Executable.BuildObjectLifecycle."
    public static let risk: ActionRisk = .boundedmutate
    public static var inputSchema: JSONValue? {
        SwiftBuildObjectInitToolInput.schema
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
