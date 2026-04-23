public struct ListSwiftSymbolsToolInput: Sendable, Codable, Hashable {
    public let path: String
    public let includeKinds: [SwiftSymbolKind]
    public let maxSymbols: Int?

    public init(
        path: String,
        includeKinds: [SwiftSymbolKind] = [],
        maxSymbols: Int? = nil
    ) {
        self.path = path
        self.includeKinds = includeKinds
        self.maxSymbols = maxSymbols
    }
}

public extension ListSwiftSymbolsToolInput {
    var clampedMaxSymbols: Int {
        guard let maxSymbols else {
            return 200
        }

        return max(1, maxSymbols)
    }

    var filtersByKind: Bool {
        !includeKinds.isEmpty
    }
}
