import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Primitives
import Schema
import SchemaMacros

@JSONSchema
public struct SwiftBuildLibraryToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Library build configuration. Defaults to release.
    public let configuration: SwiftBuildToolInput.Configuration?

    /// Keep artifacts in .build instead of exporting. Defaults to false.
    public let local: Bool?

    public init(
        configuration: SwiftBuildToolInput.Configuration? = nil,
        local: Bool? = nil
    ) {
        self.configuration = configuration
        self.local = local
    }
}

public struct SwiftBuildLibraryTool: TypedAgentTool {
    public typealias Input = SwiftBuildLibraryToolInput
    public static let identifier: AgentToolIdentifier = "swift_build_library"
    public static let description =
        "Build library products with module interfaces through Executable.BuildLibrary."
    public static let risk: ActionRisk = .privileged
    public init() {}

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        let decoded = try JSONToolBridge.decode(
            SwiftBuildLibraryToolInput.self,
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
            targetPaths: decoded.local == true
                ? [".build/"]
                : [".build/", BuildLibrary.defaultModulesRoot.path],
            summary: "Build Swift library distribution artifacts.",
            estimatedRuntimeSeconds: 300,
            sideEffects: [
                "Runs SwiftPM builds.",
                "May export module/library artifacts outside the workspace.",
            ],
            policyChecks: [
                "workspace_required",
                "typed_build_library",
                "human_review_required",
            ]
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            SwiftBuildLibraryToolInput.self,
            from: input
        )
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )
        let configuration = decoded.configuration ?? .release
        let config = Build.Config(
            mode: configuration == .debug
                ? .debug
                : .release,
            updateBuiltOnSuccess: false
        )
        let result = try await BuildLibrary.buildAndExport(
            at: workspace.rootURL,
            config: config,
            local: decoded.local ?? false,
            modulesRoot: BuildLibrary.defaultModulesRoot
        )

        return .object([
            "package": .string(result.packageName),
            "artifacts": .string(result.artifactsDir.path),
            "buildDir": .string(result.builtDir.path),
        ])
    }
}
