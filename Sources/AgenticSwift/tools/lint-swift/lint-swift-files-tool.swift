import Agentic
import AgenticExecution

public struct LintSwiftFilesTool:
    AgentTool
{
    public typealias Input = LintSwiftFilesToolInput
    public typealias Output = LintSwiftFilesToolOutput

    public static let identifier: AgentToolIdentifier =
        "lint_swift_files"
    public static let description =
        "Run every authored SwiftSemantics source rule against an explicit bounded set of Swift source files in the selected package and return per-file structured diagnostics."
    public static let risk: ActionRisk = .observe

    public static let maximumPathCount = 64

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

        return LintSwiftFilesToolOutput(
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
