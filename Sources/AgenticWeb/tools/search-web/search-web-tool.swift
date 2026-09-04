import Agentic
import AgenticExecution
import AgenticWorkspace
import Foundation
import Primitives

public struct SearchWebTool: AgentTool {
    public typealias Input = SearchWebToolInput
    public typealias Output = SearchWebToolOutput
    public static let identifier: AgentToolIdentifier = "search_web"
    public static let description = "Search the public web and return a small set of sandbox-approved result summaries."
    public static let risk: ActionRisk = .observe

    public let provider: any WebSearchProvider
    public let policy: WebAccessPolicy
    public let sessionStore: WebSearchSessionStore

    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

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
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        _ = context
        let query = try normalizedQuery(
            input.query
        )
        let limit = policy.normalizedResultLimit(
            input.limit
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
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        _ = context
        let query = try normalizedQuery(
            input.query
        )
        let limit = policy.normalizedResultLimit(
            input.limit
        )

        let response = try await provider.search(
            .init(
                query: query,
                limit: limit,
                siteRestrictions: input.siteRestrictions,
                freshnessDays: input.freshnessDays,
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

        return SearchWebToolOutput(
                searchID: record.id,
                query: response.query,
                provider: response.provider,
                fetchedAt: response.fetchedAt,
                returnedResultCount: approvedResults.count,
                results: approvedResults
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
