import Agentic
import AgenticExecution
import Workspace
import Executable
import Primitives
import Schema
import Macros

public struct SwiftCleanTool: Tool {
    @JSONSchema
    public struct Input:
        Codable,
        Sendable
    {
        public init() {}
    }

    @JSONSchema
    public struct Output: Sendable, Codable, Hashable {
        public let status: String

        public init(status: String) {
            self.status = status
        }
    }

public static let identifier: ToolIdentifier = "swift_clean"
    public static let description =
        "Clean the current SwiftPM workspace through Executable.Build.clean."
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
