public struct SearchWebToolInput: Sendable, Codable, Hashable {
    public let query: String
    public let limit: Int?
    public let siteRestrictions: [String]
    public let freshnessDays: Int?

    public init(
        query: String,
        limit: Int? = nil,
        siteRestrictions: [String] = [],
        freshnessDays: Int? = nil
    ) {
        self.query = query
        self.limit = limit
        self.siteRestrictions = siteRestrictions
        self.freshnessDays = freshnessDays
    }
}
