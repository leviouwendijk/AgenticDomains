import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Primitives
import Schema
import SchemaMacros
import Version

@JSONSchema
public struct SwiftIncrementVersionToolInput:
    Sendable,
    Codable
{
    /// Release version component to increment.
    public let level: ObjectVersionLevel

    public init(
        level: ObjectVersionLevel
    ) {
        self.level = level
    }
}


public struct SwiftIncrementVersionToolOutput: Sendable, Codable, Hashable {
    public let before: String
    public let after: String
    public let level: String
    public let path: String

    public init(before: String, after: String, level: String, path: String) {
        self.before = before
        self.after = after
        self.level = level
        self.path = path
    }
}

public struct SwiftIncrementVersionTool: AgentTool {
    public typealias Input = SwiftIncrementVersionToolInput
    public typealias Output = SwiftIncrementVersionToolOutput
    public static let identifier: AgentToolIdentifier = "swift_increment_version"
    public static let description =
        "Increment the build-object release version through Executable."
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
