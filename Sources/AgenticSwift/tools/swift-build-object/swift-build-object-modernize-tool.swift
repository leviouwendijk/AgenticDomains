import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Primitives
import Schema
import SchemaMacros

@JSONSchema
public struct SwiftBuildObjectModernizeToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Write build-object.pkl.bak before modernization. Defaults to true.
    public let backup: Bool?

    public init(
        backup: Bool? = nil
    ) {
        self.backup = backup
    }
}


public struct SwiftBuildObjectModernizeToolOutput: Sendable, Codable, Hashable {
    public let path: String
    public let name: String
    public let modernized: Bool
    public let backup: String?

    public init(path: String, name: String, modernized: Bool, backup: String?) {
        self.path = path
        self.name = name
        self.modernized = modernized
        self.backup = backup
    }
}

public struct SwiftBuildObjectModernizeTool: AgentTool {
    public typealias Input = SwiftBuildObjectModernizeToolInput
    public typealias Output = SwiftBuildObjectModernizeToolOutput
    public static let identifier: AgentToolIdentifier = "swift_build_object_modernize"
    public static let description =
        "Modernize a legacy build-object.pkl through Executable.BuildObjectLifecycle."
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
