import Agentic
import AgenticExecution

public struct LintSwiftSourceTool:
    AgentTool
{
    public typealias Input = LintSwiftSourceToolInput
    public typealias Output = SwiftRuleLintFileResult

    public static let identifier: AgentToolIdentifier =
        "lint_swift_source"
    public static let description =
        "Run every authored SwiftSemantics source rule against one Swift source file in the selected package and return structured diagnostics."
    public static let risk: ActionRisk = .observe

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

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let toolName = Self.identifier.rawValue
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: toolName
        )
        let file = try execution.projectFile(
            input.path,
            toolName: toolName
        )
        let adapter = try SwiftRuleLintAdapter()

        return try await adapter.lint(
            file: file,
            path: input.path
        )
    }
}
