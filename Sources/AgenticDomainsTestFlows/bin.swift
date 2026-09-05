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
            "agentic-apple-services-tool-surface",
            tags: [
                "agentic-domains",
                "apple",
                "calendar",
                "reminders",
                "weather",
                "location",
                "tools",
                "registration",
            ]
        ) {
            try await AgenticDomainsFlowTesting.runAgenticAppleServicesToolSurface()
        },
        TestFlow(
            "agentic-apple-services-weatherkit-rest-token",
            tags: [
                "agentic-domains",
                "apple",
                "weather",
                "weatherkit",
                "rest",
                "jwt",
                "fixture",
            ]
        ) {
            try await AgenticDomainsFlowTesting.runWeatherKitRESTTokenFixture()
        },
        TestFlow(
            "agentic-apple-services-weatherkit-rest-current-fixture",
            tags: [
                "agentic-domains",
                "apple",
                "weather",
                "weatherkit",
                "rest",
                "http",
                "fixture",
            ]
        ) {
            try await AgenticDomainsFlowTesting.runWeatherKitRESTCurrentFixture()
        },
        TestFlow(
            "agentic-apple-services-weatherkit-rest-forecast-fixture",
            tags: [
                "agentic-domains",
                "apple",
                "weather",
                "weatherkit",
                "rest",
                "http",
                "fixture",
            ]
        ) {
            try await AgenticDomainsFlowTesting.runWeatherKitRESTForecastFixture()
        },
        TestFlow(
            "agentic-apple-services-weatherkit-rest-configuration-boundary",
            tags: [
                "agentic-domains",
                "apple",
                "weather",
                "weatherkit",
                "rest",
                "environment",
                "validation",
            ]
        ) {
            try await AgenticDomainsFlowTesting.runWeatherKitRESTConfigurationBoundary()
        },
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
            "agentic-swift-structural-semantics-adapter",
            tags: [
                "agentic-domains",
                "swift",
                "structure",
                "swift-semantics",
                "adapter",
            ]
        ) {
            try await AgenticDomainsFlowTesting.runAgenticSwiftStructuralSemanticsAdapter()
        },
        TestFlow(
            "agentic-swift-semantic-tool-foundation",
            tags: [
                "agentic-domains",
                "swift",
                "semantics",
                "sourcekit-lsp",
                "tools",
            ]
        ) {
            try await AgenticDomainsFlowTesting.runAgenticSwiftSemanticToolFoundation()
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
        TestFlow(
            "agentic-swift-build-reported-failure",
            tags: [
                "agentic-domains",
                "swift",
                "build",
                "reported-failure",
                "processing",
                "observations",
            ]
        ) {
            try await AgenticDomainsFlowTesting.runSwiftBuildReportedFailure()
        },
        TestFlow(
            "agentic-web-tool-surface",
            tags: [
                "agentic-domains",
                "web",
                "tools",
                "registration",
            ]
        ) {
            try await AgenticDomainsFlowTesting.runAgenticWebToolSurface()
        },
        TestFlow(
            "agentic-git-tool-surface",
            tags: [
                "agentic-domains",
                "git",
                "tools",
                "registration",
            ]
        ) {
            try await AgenticDomainsFlowTesting.runAgenticGitToolSurface()
        },
        TestFlow(
            "agentic-git-worktree-lifecycle",
            tags: [
                "agentic-domains",
                "git",
                "worktree",
                "isolation",
            ]
        ) {
            try await AgenticDomainsFlowTesting.runAgenticGitWorktreeLifecycle()
        },
        TestFlow(
            "agentic-git-integration-preparation",
            tags: [
                "agentic-domains",
                "git",
                "integration",
                "prepare",
            ]
        ) {
            try await AgenticDomainsFlowTesting.runAgenticGitIntegrationPreparation()
        },
        TestFlow(
            "agentic-git-integration-promotion-cleanup",
            tags: [
                "agentic-domains",
                "git",
                "integration",
                "promotion",
                "cleanup",
            ]
        ) {
            try await AgenticDomainsFlowTesting.runAgenticGitIntegrationPromotionAndCleanup()
        },
    ]
}