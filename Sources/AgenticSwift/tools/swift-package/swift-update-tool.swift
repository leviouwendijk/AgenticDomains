import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Primitives

public struct SwiftUpdateTool: AgentTool {
    public typealias Input = AgenticSwiftEmptyToolInput
    public typealias Output = SwiftPackageOperationToolOutput
    public static let identifier: AgentToolIdentifier =
        "swift_package_update"

    public static let description =
        """
        Run SwiftPM dependency update for the current workspace through Executable.Package.update.
        """

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
