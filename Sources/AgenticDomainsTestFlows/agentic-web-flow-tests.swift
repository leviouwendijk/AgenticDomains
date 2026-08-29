import AgenticExecution
import AgenticWeb
import TestFlows

extension AgenticDomainsFlowTesting {
    static func runAgenticWebToolSurface() async throws -> [TestFlowDiagnostic] {
        var registry = ToolRegistry()

        try registry.register(
            AgenticWebToolSet()
        )

        try Expect.equal(
            registry.count,
            2,
            "AgenticWeb registered tool count"
        )

        let names =
            registry.definitions
                .map(\.name)
                .sorted()

        try Expect.equal(
            names,
            [
                "open_web_result",
                "search_web",
            ],
            "AgenticWeb registers the bounded search/open surface"
        )

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
            "AgenticWeb registered tools all project semantic input schemas"
        )

        return [
            .field(
                "registered",
                "\(registry.count)"
            ),
        ]
    }
}
