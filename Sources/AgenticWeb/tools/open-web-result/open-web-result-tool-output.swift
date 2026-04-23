import Foundation

public struct OpenWebResultToolOutput: Sendable, Codable, Hashable {
    public let searchID: String
    public let resultID: String
    public let title: String?
    public let url: String
    public let host: String
    public let contentType: String?
    public let fetchedAt: Date
    public let truncated: Bool
    public let text: String

    public init(
        searchID: String,
        resultID: String,
        title: String?,
        url: String,
        host: String,
        contentType: String?,
        fetchedAt: Date,
        truncated: Bool,
        text: String
    ) {
        self.searchID = searchID
        self.resultID = resultID
        self.title = title
        self.url = url
        self.host = host
        self.contentType = contentType
        self.fetchedAt = fetchedAt
        self.truncated = truncated
        self.text = text
    }
}
