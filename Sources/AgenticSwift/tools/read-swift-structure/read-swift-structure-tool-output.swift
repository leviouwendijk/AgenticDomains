import Agentic
import Position

public struct ReadSwiftStructureToolOutput: Sendable, Codable, Hashable {
    public struct Match: Sendable, Codable, Hashable {
        public let kind: String
        public let symbolName: String?
        public let summary: String?
        public let lineRange: LineRange
        public let lineCount: Int
        public let content: String

        public init(
            kind: String,
            symbolName: String?,
            summary: String?,
            lineRange: LineRange,
            lineCount: Int,
            content: String
        ) {
            self.kind = kind
            self.symbolName = symbolName
            self.summary = summary
            self.lineRange = lineRange
            self.lineCount = lineCount
            self.content = content
        }
    }

    public let path: String
    public let queryKind: String
    public let matchCount: Int
    public let matches: [Match]

    public init(
        path: String,
        queryKind: String,
        matchCount: Int,
        matches: [Match]
    ) {
        self.path = path
        self.queryKind = queryKind
        self.matchCount = matchCount
        self.matches = matches
    }
}
