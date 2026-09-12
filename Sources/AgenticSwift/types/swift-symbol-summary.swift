import Position

public struct SwiftSymbolSummary: Sendable, Codable, Hashable, Identifiable {
    public let id: String
    public let kind: SwiftSymbolKind
    public let name: String
    public let displayName: String
    public let parentType: String?
    public let lineRange: LineRange
    public let summary: String

    public init(
        kind: SwiftSymbolKind,
        name: String,
        displayName: String? = nil,
        parentType: String? = nil,
        lineRange: LineRange,
        summary: String
    ) {
        let displayName = displayName ?? name

        self.id = Self.makeIdentifier(
            kind: kind,
            displayName: displayName,
            parentType: parentType,
            lineRange: lineRange
        )
        self.kind = kind
        self.name = name
        self.displayName = displayName
        self.parentType = parentType
        self.lineRange = lineRange
        self.summary = summary
    }
}

private extension SwiftSymbolSummary {
    static func makeIdentifier(
        kind: SwiftSymbolKind,
        displayName: String,
        parentType: String?,
        lineRange: LineRange
    ) -> String {
        let parent = parentType ?? "_"
        return "\(kind.rawValue):\(parent):\(displayName):\(lineRange.start)-\(lineRange.end)"
    }
}
