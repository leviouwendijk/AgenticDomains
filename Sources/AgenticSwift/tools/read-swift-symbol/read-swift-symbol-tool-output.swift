import Position

public struct ReadSwiftSymbolToolOutput: Sendable, Codable, Hashable {
    public let path: String
    public let id: String
    public let kind: SwiftSymbolKind
    public let name: String
    public let displayName: String
    public let parentType: String?
    public let summary: String
    public let lineRange: LineRange
    public let lineCount: Int
    public let content: String

    public init(
        path: String,
        id: String,
        kind: SwiftSymbolKind,
        name: String,
        displayName: String,
        parentType: String?,
        summary: String,
        lineRange: LineRange,
        lineCount: Int,
        content: String
    ) {
        self.path = path
        self.id = id
        self.kind = kind
        self.name = name
        self.displayName = displayName
        self.parentType = parentType
        self.summary = summary
        self.lineRange = lineRange
        self.lineCount = lineCount
        self.content = content
    }
}
