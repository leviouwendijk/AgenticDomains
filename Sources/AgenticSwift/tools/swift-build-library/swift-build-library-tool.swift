import Agentic
import AgenticExecution
import Workspace
import Executable
import Primitives
import Schema
import Macros

public struct SwiftBuildLibraryTool: Tool {
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        /// Library build configuration. Defaults to release.
        public let configuration: SwiftBuildTool.Input.Configuration?

        /// Keep artifacts in .build instead of exporting. Defaults to false.
        public let local: Bool?

        public init(
            configuration: SwiftBuildTool.Input.Configuration? = nil,
            local: Bool? = nil
        ) {
            self.configuration = configuration
            self.local = local
        }
    }

    @JSONSchema
    public struct Output: Sendable, Codable, Hashable {
        public let package: String
        public let artifacts: String
        public let buildDir: String

        public init(package: String, artifacts: String, buildDir: String) {
            self.package = package
            self.artifacts = artifacts
            self.buildDir = buildDir
        }
    }

public static let identifier: ToolIdentifier = "swift_build_library"
    public static let description =
        "Build library products with module interfaces through Executable.BuildLibrary."
    public static let risk: ActionRisk = .privileged

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
