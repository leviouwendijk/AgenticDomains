import Agentic
import AgenticExecution
import AgenticSwift
import Foundation
import TestFlows

private enum AgenticSwiftPackageRuleLintFixtureError: Error {
    case missingFixture(String)
}

extension AgenticDomainsFlowTesting {
    static func runAgenticSwiftPackageRuleLintTool()
        async throws
        -> [TestFlowDiagnostic]
    {
        let fixture = try AgenticDomainsFixture.make(
            "swift-package-rule-lint-tool"
        )

        defer {
            fixture.remove()
        }

        try FileManager.default.createDirectory(
            at: fixture.url(
                "Sources/Core"
            ),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: fixture.url(
                "Sources/ForbiddenLayer"
            ),
            withIntermediateDirectories: true
        )

        try """
        // swift-tools-version: 6.2

        import PackageDescription

        let package = Package(
            name: "PackageLintFixture",
            targets: [
                .target(
                    name: "Core",
                    dependencies: [
                        .target(
                            name: "ForbiddenLayer"
                        ),
                    ]
                ),
                .target(
                    name: "ForbiddenLayer"
                ),
            ]
        )
        """.write(
            to: fixture.url(
                "Package.swift"
            ),
            atomically: true,
            encoding: .utf8
        )

        try """
        public struct CoreValue {
            public init() {}
        }
        """.write(
            to: fixture.url(
                "Sources/Core/Core.swift"
            ),
            atomically: true,
            encoding: .utf8
        )

        try """
        public struct ForbiddenLayerValue {
            public init() {}
        }
        """.write(
            to: fixture.url(
                "Sources/ForbiddenLayer/ForbiddenLayer.swift"
            ),
            atomically: true,
            encoding: .utf8
        )

        let context = AgentToolExecutionContext(
            workspace: fixture.workspace
        )
        let result = try await LintSwiftPackageTool().call(
            .init(
                forbiddenTargetDependencies: [
                    .init(
                        sourceTarget: "Core",
                        dependencyName: "ForbiddenLayer"
                    ),
                ]
            ),
            context: context
        )

        try Expect.equal(
            result.package,
            "PackageLintFixture",
            "lint_swift_package selected package"
        )
        try Expect.equal(
            result.diagnosticCount,
            1,
            "lint_swift_package diagnostic count"
        )
        try Expect.equal(
            result.errorCount,
            1,
            "lint_swift_package error count"
        )
        try Expect.equal(
            result.diagnostics.map(\.ruleID),
            [
                "forbidden_target_dependency",
            ],
            "lint_swift_package rule projection"
        )

        guard let diagnostic = result.diagnostics.first else {
            throw AgenticSwiftPackageRuleLintFixtureError.missingFixture(
                "lint_swift_package diagnostic"
            )
        }

        switch diagnostic.subject {
        case .target_dependency(
            let target,
            let dependency,
            let package
        ):
            try Expect.equal(
                target,
                "Core",
                "lint_swift_package subject target"
            )
            try Expect.equal(
                dependency,
                "ForbiddenLayer",
                "lint_swift_package subject dependency"
            )
            try Expect.equal(
                package,
                nil,
                "lint_swift_package local target package qualifier"
            )

        default:
            throw AgenticSwiftPackageRuleLintFixtureError.missingFixture(
                "target dependency lint subject"
            )
        }

        return [
            .field(
                "package",
                result.package
            ),
            .field(
                "diagnostics",
                "\(result.diagnosticCount)"
            ),
            .field(
                "errors",
                "\(result.errorCount)"
            ),
        ]
    }
}
