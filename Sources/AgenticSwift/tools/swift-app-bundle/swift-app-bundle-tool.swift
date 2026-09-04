import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Foundation
import Primitives
import Schema
import SchemaMacros

@JSONSchema
public struct SwiftAppBundleToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Previously built configuration. Defaults to release.
    public let configuration: SwiftBuildToolInput.Configuration?

    /// App bundle name. Defaults from target/package.
    public let appName: String?

    /// Executable target name.
    public let target: String?

    /// Optional workspace-relative Info.plist path.
    public let plist: String?

    /// Symlink explicit Info.plist instead of copying. Defaults to true.
    public let plistSymlink: Bool?

    /// Optional resources bundle name.
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
}


public struct SwiftAppBundleToolOutput: Sendable, Codable, Hashable {
    public let app: String
    public let buildDir: String
    public let appName: String
    public let target: String

    public init(app: String, buildDir: String, appName: String, target: String) {
        self.app = app
        self.buildDir = buildDir
        self.appName = appName
        self.target = target
    }
}

public struct SwiftAppBundleTool: AgentTool {
    public typealias Input = SwiftAppBundleToolInput
    public typealias Output = SwiftAppBundleToolOutput
    public static let identifier: AgentToolIdentifier = "swift_app_bundle"
    public static let description =
        "Create or refresh a .app bundle around already-built Swift artifacts through Executable.AppBundleCreation."
    public static let risk: ActionRisk = .boundedmutate
    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init() {}


}
