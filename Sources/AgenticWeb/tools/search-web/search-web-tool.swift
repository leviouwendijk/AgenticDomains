import Agentic
import Foundation
import Primitives

public struct SearchWebTool: StaticAgentTool {
    public static let identifier: AgentToolIdentifier = "search_web"
    public static let description = "Search the public web and return a small set of sandbox-approved result summaries."
    public static let risk: ActionRisk = .observe

    public let provider: any WebSearchProvider
    public let policy: WebAccessPolicy
    public let sessionStore: WebSearchSessionStore

    public init(
        provider: any WebSearchProvider = UnavailableWebSearchProvider(),
        policy: WebAccessPolicy = .default,
        sessionStore: WebSearchSessionStore = .init()
    ) {
        self.provider = provider
        self.policy = policy
        self.sessionStore = sessionStore
    }

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        _ = workspace

        let decoded = try JSONToolBridge.decode(
            SearchWebToolInput.self,
            from: input
        )
        let query = try normalizedQuery(
            decoded.query
        )
        let limit = policy.normalizedResultLimit(
            decoded.limit
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: nil,
            summary: """
            Search the web for "\(query)" and return up to \(limit) approved result summary item(s).
            """,
            commandPreview: "search query: \(query)",
            estimatedRuntimeSeconds: 5,
            sideEffects: [
                "external network read"
            ]
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        _ = workspace

        let decoded = try JSONToolBridge.decode(
            SearchWebToolInput.self,
            from: input
        )
        let query = try normalizedQuery(
            decoded.query
        )
        let limit = policy.normalizedResultLimit(
            decoded.limit
        )

        let response = try await provider.search(
            .init(
                query: query,
                limit: limit,
                siteRestrictions: decoded.siteRestrictions,
                freshnessDays: decoded.freshnessDays,
                safeSearch: true
            )
        )

        let approvedResults = response.results.filter { result in
            policy.allows(
                urlString: result.url
            )
        }

        let record = await sessionStore.store(
            query: response.query,
            results: approvedResults
        )

        return try JSONToolBridge.encode(
            SearchWebToolOutput(
                searchID: record.id,
                query: response.query,
                provider: response.provider,
                fetchedAt: response.fetchedAt,
                returnedResultCount: approvedResults.count,
                results: approvedResults
            )
        )
    }
}

private extension SearchWebTool {
    func normalizedQuery(
        _ rawValue: String
    ) throws -> String {
        let trimmed = rawValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            throw WebToolError.emptyQuery
        }

        return trimmed
    }
}
