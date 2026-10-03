import Agentic
import Macros
import Schema
import Workspace

public struct LintSwiftFilesTool:
    Tool
{
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        /// Swift source file paths relative to the selected Swift package root.
        public let paths: [String]

        public init(
            paths: [String]
        ) {
            self.paths = paths
        }
    }

    @JSONSchema
    public struct Output:
        Sendable,
        Codable,
        Hashable
    {
        public let files: [SwiftRuleLintFileResult]
        public let diagnosticCount: Int
        public let errorCount: Int
        public let warningCount: Int
        public let informationCount: Int
        public let hintCount: Int

        public init(
            files: [SwiftRuleLintFileResult],
            diagnosticCount: Int,
            errorCount: Int,
            warningCount: Int,
            informationCount: Int,
            hintCount: Int
        ) {
            self.files = files
            self.diagnosticCount = diagnosticCount
            self.errorCount = errorCount
            self.warningCount = warningCount
            self.informationCount = informationCount
            self.hintCount = hintCount
        }
    }

public static let identifier: ToolIdentifier =
        "lint_swift_files"
    public static let description =
        "Run every authored SwiftSemantics source rule against an explicit bounded set of Swift source files in the selected package and return per-file structured diagnostics."
    public static let risk: ActionRisk = .observe

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public static let maximumPathCount = 64

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

        guard !input.paths.isEmpty,
              input.paths.count <= Self.maximumPathCount
        else {
            throw AgenticSwiftToolError.operationFailed(
                toolName: toolName,
                operation: "lint Swift source files",
                exitCode: nil,
                signal: nil,
                detail:
                    "lint_swift_files requires between 1 and \(Self.maximumPathCount) explicit project-relative Swift source paths."
            )
        }

        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: toolName
        )
        let adapter = try SwiftRuleLintAdapter()
        var files: [SwiftRuleLintFileResult] = []

        for path in input.paths {
            let file = try execution.projectFile(
                path,
                toolName: toolName
            )
            let result = try await adapter.lint(
                file: file,
                path: path
            )

            files.append(
                result
            )
        }

        return Output(
            files: files,
            diagnosticCount: files.reduce(0) {
                $0 + $1.diagnostics.count
            },
            errorCount: files.reduce(0) {
                $0 + $1.errorCount
            },
            warningCount: files.reduce(0) {
                $0 + $1.warningCount
            },
            informationCount: files.reduce(0) {
                $0 + $1.informationCount
            },
            hintCount: files.reduce(0) {
                $0 + $1.hintCount
            }
        )
    }
}
