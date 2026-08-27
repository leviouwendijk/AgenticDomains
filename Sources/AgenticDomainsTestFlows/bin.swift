import TestFlows

@main
enum AgenticDomainsFlowTestMain {
    static func main() async {
        await TestFlowCLI.run(
            suite: AgenticDomainsFlowSuite.self
        )
    }
}

enum AgenticDomainsFlowSuite: TestFlowRegistry {
    static let title = "AgenticDomains flow tests"

    static let flows: [TestFlow] = [
        TestFlow(
            "agentic-swift-tool-surface",
            tags: [
                "agentic-domains",
                "swift",
                "tools",
                "registration",
            ]
        ) {
            try await AgenticDomainsFlowTesting.runAgenticSwiftToolSurface()
        },
        TestFlow(
            "agentic-swift-parse-fixture",
            tags: [
                "agentic-domains",
                "swift",
                "parse",
                "fixture",
            ]
        ) {
            try await AgenticDomainsFlowTesting.runSwiftParseFixture()
        },
        TestFlow(
            "agentic-swift-deployment-defaults",
            tags: [
                "agentic-domains",
                "swift",
                "deployment",
                "preflight",
            ]
        ) {
            try await AgenticDomainsFlowTesting.runDeploymentDefaults()
        },
        TestFlow(
            "agentic-swift-package-tool-names",
            tags: [
                "agentic-domains",
                "swift",
                "package",
                "preflight",
            ]
        ) {
            try await AgenticDomainsFlowTesting.runPackageToolNames()
        },
    ]
}
