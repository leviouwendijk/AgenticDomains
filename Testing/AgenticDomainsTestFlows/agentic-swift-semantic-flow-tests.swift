import Agentic
import AgenticExecution
import AgenticSwift
import Foundation
import TestFlows

extension AgenticDomainsFlowTesting {
    static func runAgenticSwiftStructuralSemanticsAdapter()
        async throws
        -> [TestFlowDiagnostic]
    {
        let fixture = try AgenticDomainsFixture.make(
            "swift-structural-semantics"
        )
        defer {
            fixture.remove()
        }

        try """
        struct Fixture {
            let value: Int

            func greet(name: String) -> String {
                "Hello \\(name)"
            }
        }
        """.write(
            to: fixture.url(
                "Fixture.swift"
            ),
            atomically: true,
            encoding: .utf8
        )

        let context = AgentToolExecutionContext(
            workspace: fixture.workspace
        )

        let listed = try await ListSwiftSymbolsTool().call(
            .init(
                path: "Fixture.swift"
            ),
            context: context
        )
        let function = try Expect.notNil(
            listed.symbols.first { symbol in
                symbol.kind == .function
                    && symbol.displayName == "greet(name:)"
            },
            "list_swift_symbols projects SwiftSemantics callable identity"
        )

        let read = try await ReadSwiftSymbolTool().call(
            .init(
                path: "Fixture.swift",
                id: function.id
            ),
            context: context
        )

        try Expect.true(
            read.content.contains(
                "func greet(name: String)"
            ),
            "read_swift_symbol reads the SwiftSemantics-selected source range"
        )

        let structure = try await ReadSwiftStructureTool().call(
            .init(
                path: "Fixture.swift",
                queryKind: .member,
                name: "greet",
                parentType: "Fixture"
            ),
            context: context
        )

        try Expect.equal(
            structure.matchCount,
            1,
            "read_swift_structure preserves member selection semantics"
        )
        try Expect.equal(
            structure.matches.first?.symbolName,
            "greet",
            "read_swift_structure projects SwiftSemantics member identity"
        )

        return [
            .field(
                "symbols",
                "\(listed.totalSymbolCount)"
            ),
            .field(
                "function",
                function.displayName
            ),
            .field(
                "structure-matches",
                "\(structure.matchCount)"
            ),
        ]
    }

    static func runAgenticSwiftSemanticToolFoundation()
        async throws
        -> [TestFlowDiagnostic]
    {
        let fixture = try AgenticDomainsFixture.make(
            "swift-semantic-tools"
        )
        defer {
            fixture.remove()
        }

        let sources = fixture.url(
            "Sources/Core"
        )
        try FileManager.default.createDirectory(
            at: sources,
            withIntermediateDirectories: true
        )

        try """
        // swift-tools-version: 6.3

        import PackageDescription

        let package = Package(
            name: "SemanticFixture",
            targets: [
                .target(
                    name: "Core"
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
        public struct SemanticFixture {
            public init() {}
        }
        """.write(
            to: sources.appendingPathComponent(
                "Core.swift"
            ),
            atomically: true,
            encoding: .utf8
        )

        let context = AgentToolExecutionContext(
            workspace: fixture.workspace
        )

        let definition = FindSwiftDefinitionTool()
        let preflight = try await definition.preflight(
            .init(
                path: "Sources/Core/Core.swift",
                line: 1,
                utf16Column: 15
            ),
            context: context
        )

        try Expect.equal(
            preflight.risk,
            .privileged,
            "compiler-semantic tools conservatively review preparation as privileged"
        )
        try Expect.true(
            preflight.targetPaths.contains {
                $0.hasSuffix(
                    "Sources/Core/Core.swift"
                )
            },
            "semantic preflight resolves project-relative source path"
        )

        let graph = try await InspectPackageGraphTool().call(
            .init(),
            context: context
        )

        try Expect.equal(
            graph.rootName,
            "SemanticFixture",
            "inspect_package_graph projects SwiftSemantics package root"
        )
        try Expect.true(
            graph.targets.contains { target in
                target.name == "Core"
            },
            "inspect_package_graph projects SwiftPM targets"
        )

        return [
            .field(
                "risk",
                preflight.risk.rawValue
            ),
            .field(
                "package",
                graph.rootName
            ),
            .field(
                "targets",
                "\(graph.targets.count)"
            ),
        ]
    }
}
