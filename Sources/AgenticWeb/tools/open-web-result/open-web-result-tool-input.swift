import Schema

/// Open one bounded result from a previously recorded web search.
@JSONSchema
public struct OpenWebResultToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Search record identifier returned by search_web.
    public let searchID: String

    /// Result identifier returned by search_web.
    public let resultID: String

    /// Optional maximum number of returned text characters.
    public let maxCharacters: Int?

    public init(
        searchID: String,
        resultID: String,
        maxCharacters: Int? = nil
    ) {
        self.searchID = searchID
        self.resultID = resultID
        self.maxCharacters = maxCharacters
    }
}
