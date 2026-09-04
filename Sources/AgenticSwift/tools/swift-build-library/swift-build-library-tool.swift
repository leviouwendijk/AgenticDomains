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


public struct SwiftBuildLibraryToolOutput: Sendable, Codable, Hashable {
    public let package: String
    public let artifacts: String
    public let buildDir: String

    public init(package: String, artifacts: String, buildDir: String) {
        self.package = package
        self.artifacts = artifacts
        self.buildDir = buildDir
    }
}

public struct SwiftBuildLibraryTool: AgentTool {
    public typealias Input = SwiftBuildLibraryToolInput
    public typealias Output = SwiftBuildLibraryToolOutput
    public static let identifier: AgentToolIdentifier = "swift_build_library"
    public static let description =
        "Build library products with module interfaces through Executable.BuildLibrary."
    public static let risk: ActionRisk = .privileged
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
