import Foundation

public struct SearchWebToolOutput: Sendable, Codable, Hashable {
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
