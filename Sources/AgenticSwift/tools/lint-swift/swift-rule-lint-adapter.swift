import Foundation
import SwiftSemantics

struct SwiftRuleLintAdapter:
    Sendable
{
    private let analyzer: SwiftSemanticRuleAnalyzer

    init() throws {
        analyzer = SwiftSemanticRuleAnalyzer(
            ruleSet: try SwiftSemanticRuleSet.all
        )
    }

    func lint(
        file: URL,
        path: String
    ) async throws -> SwiftRuleLintFileResult {
        let source = try SwiftSemanticSource(
            file: file
        )
        let analysis = try await analyzer.analyze(
            source
        )
        let diagnostics = analysis.diagnostics.map { diagnostic in
            SwiftRuleLintDiagnostic(
                ruleID: diagnostic.ruleID.rawValue,
                severity: diagnostic.severity.rawValue,
                message: diagnostic.message,
                lineRange: diagnostic.lineRange
            )
        }

        var errorCount = 0
        var warningCount = 0
        var informationCount = 0
        var hintCount = 0

        for diagnostic in analysis.diagnostics {
            switch diagnostic.severity {
            case .error:
                errorCount += 1
            case .warning:
                warningCount += 1
            case .information:
                informationCount += 1
            case .hint:
                hintCount += 1
            }
        }

        return SwiftRuleLintFileResult(
            path: path,
            diagnostics: diagnostics,
            errorCount: errorCount,
            warningCount: warningCount,
            informationCount: informationCount,
            hintCount: hintCount
        )
    }
}
