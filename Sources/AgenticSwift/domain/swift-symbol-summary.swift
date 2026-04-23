import Position

public struct SwiftSymbolSummary: Sendable, Codable, Hashable, Identifiable {
    public let id: String
    public let kind: SwiftSymbolKind
    public let name: String
    public let parentType: String?
    public let lineRange: LineRange
    public let summary: String

    public init(
        kind: SwiftSymbolKind,
        name: String,
        parentType: String? = nil,
        lineRange: LineRange,
        summary: String
    ) {
        self.id = Self.makeIdentifier(
            kind: kind,
            name: name,
            parentType: parentType,
            lineRange: lineRange
        )
        self.kind = kind
        self.name = name
        self.parentType = parentType
        self.lineRange = lineRange
        self.summary = summary
    }
}

private extension SwiftSymbolSummary {
    static func makeIdentifier(
        kind: SwiftSymbolKind,
        name: String,
        parentType: String?,
        lineRange: LineRange
    ) -> String {
        let parent = parentType ?? "_"
        return "\(kind.rawValue):\(parent):\(name):\(lineRange.start)-\(lineRange.end)"
    }
}
