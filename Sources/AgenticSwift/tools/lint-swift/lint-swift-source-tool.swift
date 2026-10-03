import Agentic
import Macros
import Schema
import Workspace

public struct LintSwiftSourceTool:
    Tool
{
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        /// Swift source file path relative to the selected Swift package root.
        public let path: String

        public init(
            path: String
        ) {
            self.path = path
        }
    }

public typealias Output = SwiftRuleLintFileResult

    public static let identifier: ToolIdentifier =
        "lint_swift_source"
    public static let description =
        "Run every authored SwiftSemantics source rule against one Swift source file in the selected package and return structured diagnostics."
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

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
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
