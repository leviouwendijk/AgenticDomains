import Agentic
import AgenticExecution
import AgenticWorkspace
import AgenticSwift
import Executable
import Foundation
import Primitives
import TestFlows

enum AgenticDomainsFlowTesting {
    static func runAgenticSwiftToolSurface() async throws -> [TestFlowDiagnostic] {
        var registry = ToolRegistry()

        try registry.register(
            AgenticSwiftToolSet()
        )

        try Expect.equal(
            registry.count,
            20,
            "AgenticSwift registered tool count"
        )

        let names = Set(
            registry.definitions.map(\.name)
        )

        let expected = [
            "swift_parse",
            "swift_package_update",
            "swift_package_resolve",
            "swift_build",
            "swift_clean",
            "swift_version",
            "swift_deployed_products",
            "swift_remove_deployed",
            "swift_increment_version",
            "swift_kill_swiftpm",
            "swift_build_library",
            "swift_build_object_init",
            "swift_build_object_modernize",
            "swift_app_bundle",
            "swift_deploy",
            "swift_run_product",
        ]

        for name in expected {
            try Expect.true(
                names.contains(name),
                "AgenticSwift registers \(name)"
            )
        }

        let missingSemanticSchemas =
            registry.capabilities
                .filter {
                    $0.semanticInputSchema == nil
                }
                .map(\.definition.name)
                .sorted()

        try Expect.equal(
            missingSemanticSchemas,
            [String](),
            "AgenticSwift registered tools all project semantic input schemas"
        )

        return [
            .field(
                "registered",
                "\(registry.count)"
            ),
            .field(
                "package-update",
                SwiftUpdateTool.identifier.rawValue
            ),
            .field(
                "package-resolve",
                SwiftResolveTool.identifier.rawValue
            ),
        ]
    }

    static func runSwiftParseFixture() async throws -> [TestFlowDiagnostic] {
        let fixture = try AgenticDomainsFixture.make(
            "swift-parse"
        )
        defer {
            fixture.remove()
        }

        let source = fixture.url(
            "Fixture.swift"
        )

        try """
        struct Fixture {
            let value: Int
        }
        """.write(
            to: source,
            atomically: true,
            encoding: .utf8
        )

        let tool = SwiftParseTool()
        let input = SwiftParseToolInput(
                path: "Fixture.swift"
            )

        let preflight = try await tool.preflight(
            input,
            context: .init(
                workspace: fixture.workspace
            )
        )

        try Expect.equal(
            preflight.risk,
            .observe,
            "swift_parse risk"
        )
        try Expect.true(
            preflight.sideEffects.isEmpty,
            "swift_parse preflight has no side effects"
        )
        try Expect.true(
            preflight.targetPaths.contains {
                $0.contains("Fixture.swift")
            },
            "swift_parse preflight targets fixture"
        )

        let encoded = try await tool.call(
            input,
            context: .init(
                workspace: fixture.workspace
            )
        )
        let output = encoded

        try Expect.true(
            output.path.contains("Fixture.swift"),
            "swift_parse output preserves fixture identity"
        )

        return [
            .field(
                "path",
                output.path
            ),
            .field(
                "risk",
                preflight.risk.rawValue
            ),
        ]
    }

    static func runDeploymentDefaults() async throws -> [TestFlowDiagnostic] {
        let fixture = try AgenticDomainsFixture.make(
            "deployment-defaults"
        )
        defer {
            fixture.remove()
        }

        let listTool = SwiftDeployedProductsTool()
        let listInput = SwiftDeployedProductsToolInput(
                includeDetails: false
            )
        let listPreflight = try await listTool.preflight(
            listInput,
            context: .init(
                workspace: fixture.workspace
            )
        )

        try Expect.equal(
            listPreflight.risk,
            .observe,
            "deployed-products risk"
        )
        try Expect.true(
            listPreflight.targetPaths.contains(
                Build.defaultDeploymentDirectory.path
            ),
            "deployed-products uses Executable deployment default"
        )

        let removeTool = SwiftRemoveDeployedTool()
        let product = "agentic-domains-fixture-do-not-remove"
        let removeInput = SwiftRemoveDeployedToolInput(
                product: product
            )
        let removePreflight = try await removeTool.preflight(
            removeInput,
            context: .init(
                workspace: fixture.workspace
            )
        )

        try Expect.equal(
            removePreflight.risk,
            .privileged,
            "remove-deployed risk"
        )

        let expectedProductPath = Build.defaultDeploymentDirectory
            .appendingPathComponent(
                product
            )
            .path

        try Expect.true(
            removePreflight.targetPaths.contains(
                expectedProductPath
            ),
            "remove-deployed uses Executable deployment default"
        )

        return [
            .field(
                "deployment-root",
                Build.defaultDeploymentDirectory.path
            ),
            .field(
                "remove-executed",
                "false"
            ),
        ]
    }

    static func runPackageToolNames() async throws -> [TestFlowDiagnostic] {
        let fixture = try AgenticDomainsFixture.make(
            "package-tool-names"
        )
        defer {
            fixture.remove()
        }

        let empty = AgenticSwiftEmptyToolInput()

        let update = SwiftUpdateTool()
        let updatePreflight = try await update.preflight(
            empty,
            context: .init(
                workspace: fixture.workspace
            )
        )

        let resolve = SwiftResolveTool()
        let resolvePreflight = try await resolve.preflight(
            empty,
            context: .init(
                workspace: fixture.workspace
            )
        )

        try Expect.equal(
            SwiftUpdateTool.identifier.rawValue,
            "swift_package_update",
            "package update identifier"
        )
        try Expect.equal(
            SwiftResolveTool.identifier.rawValue,
            "swift_package_resolve",
            "package resolve identifier"
        )
        try Expect.equal(
            updatePreflight.risk,
            .privileged,
            "package update preflight risk"
        )
        try Expect.equal(
            resolvePreflight.risk,
            .privileged,
            "package resolve preflight risk"
        )
        let expectedPackageResolvedPath = fixture.url(
            "Package.resolved"
        ).path

        try Expect.true(
            updatePreflight.targetPaths.contains(
                expectedPackageResolvedPath
            ),
            "package update preflight resolves Package.resolved in the selected workspace"
        )
        try Expect.true(
            resolvePreflight.targetPaths.contains(
                expectedPackageResolvedPath
            ),
            "package resolve preflight resolves Package.resolved in the selected workspace"
        )

        return [
            .field(
                "update",
                SwiftUpdateTool.identifier.rawValue
            ),
            .field(
                "resolve",
                SwiftResolveTool.identifier.rawValue
            ),
            .field(
                "executed",
                "false"
            ),
        ]
    }

    static func runSwiftBuildReportedFailure() async throws -> [TestFlowDiagnostic] {
        let fixture = try AgenticDomainsFixture.make(
            "swift-build-reported-failure"
        )
        defer {
            fixture.remove()
        }

        let sources = fixture.url(
            "Sources/Broken"
        )
        try FileManager.default.createDirectory(
            at: sources,
            withIntermediateDirectories: true
        )

        try """
        // swift-tools-version: 6.2

        import PackageDescription

        let package = Package(
            name: "Broken",
            targets: [
                .executableTarget(
                    name: "Broken"
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
        let = intentionallyInvalidSwift
        """.write(
            to: sources.appendingPathComponent(
                "main.swift"
            ),
            atomically: true,
            encoding: .utf8
        )

        let tool = SwiftBuildTool()
        let registry = try ToolRegistry {
            tool
        }
        let call = AgentToolCall(
            id: "swift-build-reported-failure",
            name: tool.identifier.rawValue,
            input: try JSONToolBridge.encode(
                SwiftBuildToolInput(
                    configuration: .debug
                )
            )
        )
        let result = try await registry.execute(
            call,
            context: .init(
                workspace: fixture.workspace
            )
        )
        let output = try JSONToolBridge.decode(
            SwiftBuildToolOutput.self,
            from: result.output
        )
        let processing = try Expect.notNil(
            result.processing,
            "failed Swift build retains registered result processing"
        )
        let projection = try Expect.notNil(
            processing.projection,
            "failed Swift build retains its semantic projection"
        )

        try Expect.true(
            result.isError,
            "failed Swift build is a model-visible reported failure"
        )
        try Expect.true(
            !output.isSuccess,
            "failed Swift build preserves typed semantic output"
        )
        try Expect.equal(
            projection.status,
            "failed",
            "failed Swift build still runs typed process"
        )
        try Expect.true(
            !processing.observations.isEmpty,
            "failed Swift build retains captured build observations"
        )

        return [
            .field(
                "is-error",
                "\(result.isError)"
            ),
            .field(
                "exit",
                "\(output.exitCode)"
            ),
            .field(
                "projection",
                projection.status
            ),
            .field(
                "observations",
                "\(processing.observations.count)"
            ),
        ]
    }
}

private struct AgenticDomainsFixture {
    let root: URL
    let workspace: AgentWorkspace

    static func make(
        _ name: String
    ) throws -> Self {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "agentic-domains-\(name)-\(UUID().uuidString)",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )

        return .init(
            root: root,
            workspace: try AgentWorkspace(
                root: root
            )
        )
    }

    func url(
        _ relativePath: String
    ) -> URL {
        root.appendingPathComponent(
            relativePath
        )
    }

    func remove() {
        try? FileManager.default.removeItem(
            at: root
        )
    }
}