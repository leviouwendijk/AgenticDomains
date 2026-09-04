import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Primitives
import Schema
import SchemaMacros

@JSONSchema
public struct SwiftKillSwiftPMToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Use SIGKILL immediately. Defaults to false.
    public let force: Bool?

    /// Only list processes that would be terminated. Defaults to false.
    public let dryRun: Bool?

    public init(
        force: Bool? = nil,
        dryRun: Bool? = nil
    ) {
        self.force = force
        self.dryRun = dryRun
    }
}


public struct SwiftKillSwiftPMToolOutput: Sendable, Codable, Hashable {
    public struct Process: Sendable, Codable, Hashable {
        public let pid: String
        public let command: String

        public init(pid: String, command: String) {
            self.pid = pid
            self.command = command
        }
    }

    public let count: String
    public let dryRun: Bool
    public let processes: [Process]

    public init(count: String, dryRun: Bool, processes: [Process]) {
        self.count = count
        self.dryRun = dryRun
        self.processes = processes
    }
}

public struct SwiftKillSwiftPMTool: AgentTool {
    public typealias Input = SwiftKillSwiftPMToolInput
    public typealias Output = SwiftKillSwiftPMToolOutput
    public static let identifier: AgentToolIdentifier = "swift_kill_swiftpm"
    public static let description =
        "Inspect and terminate Swift/SwiftPM process trees through Executable.SwiftPMProcesses."
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
