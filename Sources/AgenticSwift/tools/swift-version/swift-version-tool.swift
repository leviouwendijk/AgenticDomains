import Agentic
import AgenticExecution
import Workspace
import Executable
import Primitives
import Schema
import Version
import Macros


public struct SwiftVersionTool: Tool {
    @JSONSchema
    public struct Input:
        Codable,
        Sendable
    {
        public init() {}
    }

    @JSONSchema
    public struct Output:
        Sendable,
        Codable,
        Hashable
    {
        public let name: String
        public let types: [String]
        public let compiled: String
        public let release: String
        public let ahead: Int?
        public let behind: Int?

        public init(
            name: String,
            types: [String],
            compiled: String,
            release: String,
            ahead: Int?,
            behind: Int?
        ) {
            self.name = name
            self.types = types
            self.compiled = compiled
            self.release = release
            self.ahead = ahead
            self.behind = behind
        }
    }

public static let identifier: ToolIdentifier = "swift_version"
    public static let description =
        "Inspect build-object and compiled Swift project versions through Executable."
    public static let risk: ActionRisk = .observe

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
