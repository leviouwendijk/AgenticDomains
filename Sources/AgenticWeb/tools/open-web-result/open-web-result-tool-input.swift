public struct OpenWebResultToolInput: Sendable, Codable, Hashable {
    public let searchID: String
    public let resultID: String
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
