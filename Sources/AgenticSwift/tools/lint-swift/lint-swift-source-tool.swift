import Agentic
import Macros
import Schema
import Workspace

public extension SwiftLang.Tools {
    @Tool("lint_swift_source")
    struct LintSource {
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

        public static let purpose =
            "Run every authored SwiftSemantics source rule against one Swift source file in the selected package and return structured diagnostics."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(
            _ input: Input,
            in context: ToolContext
        ) async throws -> Output {
            let toolName = Self.definition.identifier.rawValue
            let execution = try SwiftSemanticToolSupport.resolve(
                context.workspace,
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
}
