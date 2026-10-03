import Agentic
import Workspace
import Executable
import Foundation
import Primitives
import Schema
import Macros

public struct SwiftAppBundleTool: Tool {
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        /// Previously built configuration. Defaults to release.
        public let configuration: SwiftLang.Tools.Build.Input.Configuration?

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
            configuration: SwiftLang.Tools.Build.Input.Configuration? = nil,
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

    @JSONSchema
    public struct Output: Sendable, Codable, Hashable {
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

public static let identifier: ToolIdentifier = "swift_app_bundle"
    public static let description =
        "Create or refresh a .app bundle around already-built Swift artifacts through Executable.AppBundleCreation."
    public static let risk: ActionRisk = .boundedmutate

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )
    public var identifier: ToolIdentifier {
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
