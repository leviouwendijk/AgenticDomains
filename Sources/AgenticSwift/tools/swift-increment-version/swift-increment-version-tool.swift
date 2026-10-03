import Agentic
import Workspace
import Executable
import Primitives
import Schema
import Macros
import Version

public struct SwiftIncrementVersionTool: Tool {
    @JSONSchema
    public struct Input:
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

    @JSONSchema
    public struct Output: Sendable, Codable, Hashable {
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

public static let identifier: ToolIdentifier = "swift_increment_version"
    public static let description =
        "Increment the build-object release version through Executable."
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
