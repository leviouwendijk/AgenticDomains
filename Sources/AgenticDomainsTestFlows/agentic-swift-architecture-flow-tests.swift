import AgenticExecution
import AgenticSwift
import Foundation
import TestFlows

extension AgenticDomainsFlowTesting {
    static func runAgenticSwiftArchitectureTools()
        async throws
        -> [TestFlowDiagnostic]
    {
        let fixture = try AgenticDomainsFixture.make(
            "swift-architecture-tools"
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
            name: "ArchitectureFixture",
            products: [
                .library(
                    name: "Core",
                    targets: ["Core"]
                ),
            ],
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
        public protocol ArchitectureService {
            func execute()
        }

        public struct ArchitectureFixture:
            ArchitectureService
        {
            public init() {}

            public func execute() {}
        }

        struct InternalArchitectureValue {
            let value: Int
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

        let architecture = try await InspectSwiftArchitectureTool().call(
            .init(
                minimumAccessLevel: .internal,
                refresh: true
            ),
            context: context
        )

        try Expect.equal(
            architecture.packageName,
            "ArchitectureFixture",
            "architecture inspection projects live SwiftPM package identity"
        )

        try Expect.equal(
            architecture.returnedSymbolCount,
            architecture.totalSymbolCount,
            "architecture inspection returns every captured symbol when symbolLimit is omitted"
        )

        try Expect.equal(
            architecture.truncated,
            false,
            "architecture inspection is complete when symbolLimit is omitted"
        )

        let limitedArchitecture = try await InspectSwiftArchitectureTool().call(
            .init(
                minimumAccessLevel: .internal,
                symbolLimit: 1,
                refresh: false
            ),
            context: context
        )

        try Expect.equal(
            limitedArchitecture.returnedSymbolCount,
            1,
            "architecture inspection honors an explicit symbol limit"
        )

        try Expect.equal(
            limitedArchitecture.truncated,
            true,
            "architecture inspection reports truncation when an explicit symbol limit omits symbols"
        )

        try Expect.true(
            architecture.modules.contains(
                "Core"
            ),
            "architecture inspection projects compiler module topology"
        )

        try Expect.true(
            architecture.symbols.contains {
                $0.name == "InternalArchitectureValue"
                    && $0.module == "Core"
            },
            "architecture inspection includes internal symbols and module membership"
        )

        let search = try await SearchSwiftArchitectureTool().call(
            .init(
                query: "ArchitectureFixture",
                module: "Core",
                minimumAccessLevel: .internal
            ),
            context: context
        )

        try Expect.true(
            search.symbols.contains {
                $0.name == "ArchitectureFixture"
            },
            "architecture search resolves a symbol from the cached live semantic graph"
        )

        guard let fixtureSymbol = search.symbols.first(
            where: {
                $0.name == "ArchitectureFixture"
            }
        ) else {
            throw AgenticDomainsArchitectureFlowError
                .missingFixtureSymbol
        }

        let symbol = try await InspectSwiftArchitectureSymbolTool().call(
            .init(
                identity: fixtureSymbol.identity,
                minimumAccessLevel: .internal
            ),
            context: context
        )

        try Expect.equal(
            symbol.symbol?.identity,
            Optional(
                fixtureSymbol.identity
            ),
            "exact architecture-symbol inspection preserves semantic symbol identity"
        )

        return [
            .field(
                "package",
                architecture.packageName
            ),
            .field(
                "modules",
                "\(architecture.modules.count)"
            ),
            .field(
                "symbols",
                "\(architecture.totalSymbolCount)"
            ),
            .field(
                "search-matches",
                "\(search.totalMatchCount)"
            ),
        ]
    }
}

private enum AgenticDomainsArchitectureFlowError:
    Error
{
    case missingFixtureSymbol
}
