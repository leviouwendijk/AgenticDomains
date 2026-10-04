import Agentic
import Macros
import Schema
import Workspace
import SwiftSemantics

public extension SwiftLang.Tools {
    @Tool("lint_swift_package")
    struct LintPackage {
        @JSONSchema
        public struct Input:
            Sendable,
            Codable,
            Hashable
        {
            public let forbiddenTargetDependencies:
                [LintSwiftPackageForbiddenTargetDependency]
            public let forbiddenPackageDependencies: [String]

            public init(
                forbiddenTargetDependencies:
                    [LintSwiftPackageForbiddenTargetDependency] = [],
                forbiddenPackageDependencies: [String] = []
            ) {
                self.forbiddenTargetDependencies =
                    forbiddenTargetDependencies
                self.forbiddenPackageDependencies =
                    forbiddenPackageDependencies
            }
        }

        @JSONSchema
        public struct Output:
            Sendable,
            Codable,
            Hashable
        {
            public let package: String
            public let diagnostics: [SwiftPackageRuleLintDiagnostic]
            public let diagnosticCount: Int
            public let errorCount: Int
            public let warningCount: Int
            public let informationCount: Int
            public let hintCount: Int

            public init(
                package: String,
                diagnostics: [SwiftPackageRuleLintDiagnostic],
                diagnosticCount: Int,
                errorCount: Int,
                warningCount: Int,
                informationCount: Int,
                hintCount: Int
            ) {
                self.package = package
                self.diagnostics = diagnostics
                self.diagnosticCount = diagnosticCount
                self.errorCount = errorCount
                self.warningCount = warningCount
                self.informationCount = informationCount
                self.hintCount = hintCount
            }
        }

        public static let purpose =
            "Analyze the selected Swift package graph against explicit forbidden direct package and target dependency policies and return structured diagnostics."
        public static let risk: ActionRisk = .privileged

        public init() {}

        public func call(
            _ input: Input,
            workspace context: WorkspaceContext?
        ) async throws -> Output {
            let toolName = Self.definition.identifier.rawValue
            let execution = try SwiftSemanticToolSupport.resolve(
                context,
                toolName: toolName
            )
            let workspace = await SwiftSemanticToolSupport.semanticWorkspace(
                for: execution
            )
            let graph = try await workspace.packageGraph()

            let targetRule =
                SwiftSemanticPackageRules.Dependencies
                    .ForbiddenTargetDependency(
                        forbidden:
                            input.forbiddenTargetDependencies.map { relation in
                                SwiftSemanticForbiddenTargetDependency(
                                    sourceTarget: relation.sourceTarget,
                                    dependencyName: relation.dependencyName,
                                    dependencyPackage:
                                        relation.dependencyPackage
                                )
                            }
                    )
            let packageRule =
                SwiftSemanticPackageRules.Dependencies
                    .ForbiddenPackageDependency(
                        identities:
                            input.forbiddenPackageDependencies
                    )
            let analyzer = SwiftSemanticPackageRuleAnalyzer(
                ruleSet: try SwiftSemanticPackageRuleSet(
                    rules: [
                        targetRule,
                        packageRule,
                    ]
                )
            )
            let analysis = try await analyzer.analyze(
                graph
            )
            let diagnostics = analysis.diagnostics.map { diagnostic in
                SwiftPackageRuleLintDiagnostic(
                    ruleID: diagnostic.ruleID.rawValue,
                    severity: diagnostic.severity.rawValue,
                    message: diagnostic.message,
                    subject: Self.subject(
                        diagnostic.subject
                    )
                )
            }

            return .init(
                package: graph.rootName,
                diagnostics: diagnostics,
                diagnosticCount: diagnostics.count,
                errorCount: analysis.diagnostics.count { diagnostic in
                    diagnostic.severity == .error
                },
                warningCount: analysis.diagnostics.count { diagnostic in
                    diagnostic.severity == .warning
                },
                informationCount: analysis.diagnostics.count { diagnostic in
                    diagnostic.severity == .information
                },
                hintCount: analysis.diagnostics.count { diagnostic in
                    diagnostic.severity == .hint
                }
            )
        }
    }
}

private extension SwiftLang.Tools.LintPackage {
    static func subject(
        _ subject: SwiftSemanticPackageRuleSubject
    ) -> SwiftPackageRuleLintSubject {
        switch subject {
        case .package(let identity, let name):
            return .package(
                identity: identity,
                name: name
            )

        case .declared_package_dependency(
            let identity,
            let location
        ):
            return .declared_package_dependency(
                identity: identity,
                location: location
            )

        case .product(let name):
            return .product(name)

        case .target(let name):
            return .target(name)

        case .target_dependency(
            let target,
            let dependency,
            let package
        ):
            return .target_dependency(
                target: target,
                dependency: dependency,
                package: package
            )
        }
    }
}
