import Agentic
import AgenticExecution
import AgenticSwift
import Foundation
import TestFlows

extension AgenticDomainsFlowTesting {
    static func runAgenticSwiftRuleLintTools()
        async throws
        -> [TestFlowDiagnostic]
    {
        let fixture = try AgenticDomainsFixture.make(
            "swift-rule-lint-tools"
        )

        defer {
            fixture.remove()
        }

        try """
        enum FixtureMode: String {
            case enabled = "enabled"
        }

        struct Fixture {
          func validateInput() {
                let value: Int? = 1
                _ = value!
            }
        }
        """.write(
            to: fixture.url(
                "Fixture.swift"
            ),
            atomically: true,
            encoding: .utf8
        )

        try """
        struct CleanFixture {
            let value: Int
        }
        """.write(
            to: fixture.url(
                "Clean.swift"
            ),
            atomically: true,
            encoding: .utf8
        )

        let context = AgentToolExecutionContext(
            workspace: fixture.workspace
        )

        let single = try await LintSwiftSourceTool().call(
            .init(
                path: "Fixture.swift"
            ),
            context: context
        )
        let observedRuleIDs = Set(
            single.diagnostics.map(\.ruleID)
        )
        let expectedRuleIDs: Set<String> = [
            "force_unwrap",
            "redundant_string_enum_raw_value",
            "validate_method",
            "indentation",
        ]
        let missingRuleIDs = expectedRuleIDs.subtracting(
            observedRuleIDs
        )

        try Expect.equal(
            missingRuleIDs,
            Set<String>(),
            "lint_swift_source exposes independent SwiftSemanticRuleSet.all diagnostics"
        )
        try Expect.equal(
            single.errorCount >= 2,
            true,
            "lint_swift_source projects error severities"
        )

        let multi = try await LintSwiftFilesTool().call(
            .init(
                paths: [
                    "Fixture.swift",
                    "Clean.swift",
                ]
            ),
            context: context
        )

        try Expect.equal(
            multi.files.map(\.path),
            [
                "Fixture.swift",
                "Clean.swift",
            ],
            "lint_swift_files preserves explicit input order"
        )
        try Expect.equal(
            multi.files[1].diagnostics.isEmpty,
            true,
            "lint_swift_files keeps clean files in the structured result"
        )
        try Expect.equal(
            multi.diagnosticCount,
            multi.files.reduce(0) {
                $0 + $1.diagnostics.count
            },
            "lint_swift_files diagnostic aggregate"
        )

        return [
            .field(
                "single_diagnostics",
                "\(single.diagnostics.count)"
            ),
            .field(
                "multi_files",
                "\(multi.files.count)"
            ),
            .field(
                "multi_diagnostics",
                "\(multi.diagnosticCount)"
            ),
        ]
    }
}
