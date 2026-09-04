import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Primitives
import Schema


public struct SwiftCleanToolOutput: Sendable, Codable, Hashable {
    public let status: String

    public init(status: String) {
        self.status = status
    }
}

public struct SwiftCleanTool: AgentTool {
    public typealias Input = AgenticSwiftEmptyToolInput
    public typealias Output = SwiftCleanToolOutput
    public static let identifier: AgentToolIdentifier = "swift_clean"
    public static let description =
        "Clean the current SwiftPM workspace through Executable.Build.clean."
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
