import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Foundation
import Primitives

public struct SwiftAppBundleToolInput:
    Sendable,
    Codable,
    Hashable
{
    public let configuration: SwiftBuildToolInput.Configuration?
    public let appName: String?
    public let target: String?
    public let plist: String?
    public let plistSymlink: Bool?
    public let resourcesBundle: String?

    public init(
        configuration: SwiftBuildToolInput.Configuration? = nil,
        appName: String? = nil,
        target: String? = nil,
        plist: String? = nil,
        plistSymlink: Bool? = nil,
        resourcesBundle: String? = nil
    ) {
        self.configuration = configuration
        self.appName = appName
        self.target = target
        self.plist = plist
        self.plistSymlink = plistSymlink
        self.resourcesBundle = resourcesBundle
    }

    public static var schema: JSONValue {
        JSONSchema.object {
            JSONSchema.string(
                "configuration",
                description: "Previously built configuration. Defaults to release.",
                cases: SwiftBuildToolInput.Configuration.allCases.map(\.rawValue)
            )
            JSONSchema.string(
                "appName",
                description: "App bundle name. Defaults from target/package."
            )
            JSONSchema.string(
                "target",
                description: "Executable target name."
            )
            JSONSchema.string(
                "plist",
                description: "Optional workspace-relative Info.plist path."
            )
            JSONSchema.boolean(
                "plistSymlink",
                description: "Symlink explicit Info.plist instead of copying. Defaults to true."
            )
            JSONSchema.string(
                "resourcesBundle",
                description: "Optional resources bundle name."
            )
        }
    }
}

public struct SwiftAppBundleTool: StaticAgentTool {
    public static let identifier: AgentToolIdentifier = "swift_app_bundle"
    public static let description =
        "Create or refresh a .app bundle around already-built Swift artifacts through Executable.AppBundleCreation."
    public static let risk: ActionRisk = .boundedmutate
    public static var inputSchema: JSONValue? {
        SwiftAppBundleToolInput.schema
    }

    public init() {}

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        let decoded = try JSONToolBridge.decode(
            SwiftAppBundleToolInput.self,
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
            targetPaths: [
                "\(decoded.appName ?? decoded.target ?? workspace.rootURL.lastPathComponent).app",
            ],
            summary: "Create or refresh the workspace app bundle.",
            estimatedWriteCount: 4,
            sideEffects: [
                "Creates or replaces app-bundle symlinks and Info.plist materialization.",
                "Uses already-built artifacts under .build and does not run a build itself.",
            ],
            policyChecks: [
                "workspace_required",
                "typed_app_bundle_creation",
            ]
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            SwiftAppBundleToolInput.self,
            from: input
        )
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )

        let plist: URL?
        if let raw = decoded.plist {
            let path = try workspace.resolve(
                raw,
                type: .file
            )
            plist = try workspace.absoluteURL(
                for: path,
                type: .file
            )
        } else {
            plist = nil
        }

        let result = try await AppBundleCreation.create(
            .init(
                project: workspace.rootURL,
                appName: decoded.appName,
                target: decoded.target,
                configuration: decoded.configuration == .debug
                    ? .debug
                    : .release,
                plist: plist,
                plistSymlink: decoded.plistSymlink ?? true,
                resourcesBundle: decoded.resourcesBundle
            )
        )

        return .object([
            "app": .string(result.appDirectory.path),
            "buildDir": .string(result.buildDirectory.path),
            "appName": .string(result.appName),
            "target": .string(result.target),
        ])
    }
}
