import Foundation

public struct WebSearchRequest: Sendable, Codable, Hashable {
    public let query: String
    public let limit: Int
    public let siteRestrictions: [String]
    public let freshnessDays: Int?
    public let safeSearch: Bool

    public init(
        query: String,
        limit: Int,
        siteRestrictions: [String] = [],
        freshnessDays: Int? = nil,
        safeSearch: Bool = true
    ) {
        self.query = query
        self.limit = limit
        self.siteRestrictions = siteRestrictions
        self.freshnessDays = freshnessDays
        self.safeSearch = safeSearch
    }
}

public struct WebSearchResultSummary: Sendable, Codable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let url: String
    public let displayHost: String
    public let snippet: String?

    public init(
        id: String,
        title: String,
        url: String,
        displayHost: String,
        snippet: String?
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.displayHost = displayHost
        self.snippet = snippet
    }
}

public struct WebSearchResponse: Sendable, Codable, Hashable {
    public let query: String
    public let results: [WebSearchResultSummary]
    public let provider: String
    public let fetchedAt: Date

    public init(
        query: String,
        results: [WebSearchResultSummary],
        provider: String,
        fetchedAt: Date
    ) {
        self.query = query
        self.results = results
        self.provider = provider
        self.fetchedAt = fetchedAt
    }
}

public struct WebFetchRequest: Sendable, Codable, Hashable {
    public let url: String
    public let maxBytes: Int
    public let maxCharacters: Int

    public init(
        url: String,
        maxBytes: Int,
        maxCharacters: Int
    ) {
        self.url = url
        self.maxBytes = maxBytes
        self.maxCharacters = maxCharacters
    }
}

public struct WebFetchResponse: Sendable, Codable, Hashable {
    public let requestedURL: String
    public let finalURL: String
    public let title: String?
    public let contentType: String?
    public let text: String
    public let fetchedAt: Date

    public init(
        requestedURL: String,
        finalURL: String,
        title: String?,
        contentType: String?,
        text: String,
        fetchedAt: Date
    ) {
        self.requestedURL = requestedURL
        self.finalURL = finalURL
        self.title = title
        self.contentType = contentType
        self.text = text
        self.fetchedAt = fetchedAt
    }
}
