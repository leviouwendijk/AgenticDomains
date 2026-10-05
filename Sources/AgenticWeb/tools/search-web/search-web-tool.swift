import Agentic
import Foundation
import Macros
import Schema
import Workspace

public extension Web.Tools {
    @Tool("search_web")
    struct Search {
        @JSONSchema
        public struct Input:
            Sendable,
            Codable,
            Hashable
        {
            /// Search query text.
            public let query: String

            /// Optional result limit. The active WebAccessPolicy clamps the final value.
            public let limit: Int?

            /// Optional provider site restrictions. Omit for no site restriction.
            public let siteRestrictions: [String]?

            /// Optional freshness window in days.
            public let freshnessDays: Int?

            public init(
                query: String,
                limit: Int? = nil,
                siteRestrictions: [String]? = nil,
                freshnessDays: Int? = nil
            ) {
                self.query = query
                self.limit = limit
                self.siteRestrictions = siteRestrictions
                self.freshnessDays = freshnessDays
            }
        }

        @JSONSchema
        public struct Output:
            Sendable,
            Codable,
            Hashable
        {
            public let searchID: String
            public let query: String
            public let provider: String
            public let fetchedAt: Date
            public let returnedResultCount: Int
            public let results: [WebSearchResultSummary]

            public init(
                searchID: String,
                query: String,
                provider: String,
                fetchedAt: Date,
                returnedResultCount: Int,
                results: [WebSearchResultSummary]
            ) {
                self.searchID = searchID
                self.query = query
                self.provider = provider
                self.fetchedAt = fetchedAt
                self.returnedResultCount = returnedResultCount
                self.results = results
            }
        }

        public static let purpose =
            "Search the public web and return a small set of sandbox-approved result summaries."
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
            _ input: Input,
            in _: ToolContext
        ) async throws -> ToolPreflight {
            let query = try normalizedQuery(
                input.query
            )
            let limit = policy.normalizedResultLimit(
                input.limit
            )

            return .init(
                tool: Self.definition.identifier,
                risk: Self.risk,
                summary: "Search the web for \"\(query)\" and return up to \(limit) approved result summary item(s).",
                estimates: .init(
                    runtime: 5
                ),
                preview: .init(
                    command: "search query: \(query)"
                ),
                sideEffects: [
                    "external network read",
                ]
            )
        }

        public func call(
            _ input: Input,
            in _: ToolContext
        ) async throws -> Output {
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
                    siteRestrictions: input.siteRestrictions ?? [],
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

            return Output(
                searchID: record.id,
                query: response.query,
                provider: response.provider,
                fetchedAt: response.fetchedAt,
                returnedResultCount: approvedResults.count,
                results: approvedResults
            )
        }

        private func normalizedQuery(
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
}
