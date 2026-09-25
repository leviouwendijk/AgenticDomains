import Macros
import Position
import Schema

@JSONSchema
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

@JSONSchema
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

