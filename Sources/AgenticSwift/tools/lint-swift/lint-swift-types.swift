import Macros
import Position
import Schema

@JSONSchema
public struct LintSwiftSourceToolInput:
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

@JSONSchema
public struct LintSwiftFilesToolInput:
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

public struct SwiftRuleLintDiagnostic:
    Sendable,
    Codable,
    Hashable
{
    public let ruleID: String
    public let severity: String
    public let message: String
    public let lineRange: LineRange?

    public init(
        ruleID: String,
        severity: String,
        message: String,
        lineRange: LineRange?
    ) {
        self.ruleID = ruleID
        self.severity = severity
        self.message = message
        self.lineRange = lineRange
    }
}

public struct SwiftRuleLintFileResult:
    Sendable,
    Codable,
    Hashable
{
    public let path: String
    public let diagnostics: [SwiftRuleLintDiagnostic]
    public let errorCount: Int
    public let warningCount: Int
    public let informationCount: Int
    public let hintCount: Int

    public init(
        path: String,
        diagnostics: [SwiftRuleLintDiagnostic],
        errorCount: Int,
        warningCount: Int,
        informationCount: Int,
        hintCount: Int
    ) {
        self.path = path
        self.diagnostics = diagnostics
        self.errorCount = errorCount
        self.warningCount = warningCount
        self.informationCount = informationCount
        self.hintCount = hintCount
    }
}

public struct LintSwiftFilesToolOutput:
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
