public struct ListSwiftSymbolsToolOutput: Sendable, Codable, Hashable {
    public let path: String
    public let totalSymbolCount: Int
    public let returnedSymbolCount: Int
    public let truncated: Bool
    public let symbols: [SwiftSymbolSummary]

    public init(
        path: String,
        totalSymbolCount: Int,
        returnedSymbolCount: Int,
        truncated: Bool,
        symbols: [SwiftSymbolSummary]
    ) {
        self.path = path
        self.totalSymbolCount = totalSymbolCount
        self.returnedSymbolCount = returnedSymbolCount
        self.truncated = truncated
        self.symbols = symbols
    }
}
