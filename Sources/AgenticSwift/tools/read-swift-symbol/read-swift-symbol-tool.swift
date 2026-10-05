import Agentic
import Macros
import Workspace
import Foundation
import Position
import Primitives
import Schema
import Path

public struct ReadSwiftSymbolTool: Tool {
    @JSONSchema
    public struct Input: Sendable, Codable, Hashable {
        /// Swift source file path relative to the current Agentic workspace.
        public let path: String

        /// Exact symbol identifier returned by list_swift_symbols. Supply id or displayName.
        public let id: String?

        /// Exact symbol display name returned by list_swift_symbols. Supply displayName or id.
        public let displayName: String?

        /// Optional parent type used when disambiguating displayName.
        public let parentType: String?

        /// Optional symbol kind used when disambiguating displayName.
        public let kind: SwiftSymbolKind?

        /// Whether returned source content includes line-number prefixes. Defaults to true.
        @Schema(required: false)
        public let includeLineNumbers: Bool

        public init(
            path: String,
            id: String? = nil,
            displayName: String? = nil,
            parentType: String? = nil,
            kind: SwiftSymbolKind? = nil,
            includeLineNumbers: Bool = true
        ) {
            self.path = path
            self.id = id
            self.displayName = displayName
            self.parentType = parentType
            self.kind = kind
            self.includeLineNumbers = includeLineNumbers
        }
    }

    @JSONSchema
    public struct Output: Sendable, Codable, Hashable {
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

public static let identifier: ToolIdentifier = "read_swift_symbol"
    public static let description = "Read one exact Swift symbol from a Swift source file in the workspace, disambiguated by symbol id or display name."
    public static let risk: ActionRisk = .observe

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public let collector: SwiftSymbolCollector

    public var identifier: ToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init(
        collector: SwiftSymbolCollector = .init()
    ) {
        self.collector = collector
    }

    public func preflight(
        _ input: Input,
        in context: ToolContext
    ) async throws -> ToolPreflight {

        guard input.hasLookup else {
            throw ReadSwiftSymbolToolError.missingLookup
        }

        let renderedPath = try AgenticSwiftToolSupport.resolvedPreflightPath(
            input.path,
            workspace: context.workspace
        )

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary: summary(
                for: input,
                renderedPath: renderedPath
            ),
            access: .init(
                targets: [renderedPath]
            )
        )
    }

    public func call(
        _ input: Input,
        in context: ToolContext
    ) async throws -> Output {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            context.workspace,
            toolName: Self.definition.identifier.rawValue
        )

        guard input.hasLookup else {
            throw ReadSwiftSymbolToolError.missingLookup
        }

        let file = try AgenticSwiftToolSupport.projectFileURL(
            input.path,
            workspace: workspace,
            toolName: Self.definition.identifier.rawValue
        )
        let symbol = try resolveSymbol(
            for: input,
            in: file
        )
        let read = try AgenticSwiftToolSupport.readLines(
            from: file,
            range: symbol.lineRange
        )

        return Output(
            path: input.path,
                id: symbol.id,
                kind: symbol.kind,
                name: symbol.name,
                displayName: symbol.displayName,
                parentType: symbol.parentType,
                summary: symbol.summary,
                lineRange: symbol.lineRange,
            lineCount: read.lineCount,
            content: AgenticSwiftToolSupport.renderLines(
                read.lines,
                startingAt: read.startLine,
                includeLineNumbers: input.includeLineNumbers
            )
        )
    }
}

private extension ReadSwiftSymbolTool {
    func resolveSymbol(
        for input: ReadSwiftSymbolTool.Input,
        in file: URL
    ) throws -> SwiftSymbolSummary {
        let symbols = try collector.collect(
            in: file
        )

        let candidates: [SwiftSymbolSummary]
        if let id = input.normalizedID {
            candidates = symbols.filter { symbol in
                symbol.id == id
            }
        } else if let displayName = input.normalizedDisplayName {
            candidates = symbols.filter { symbol in
                guard symbol.displayName == displayName else {
                    return false
                }

                if let parentType = input.parentType,
                   symbol.parentType != parentType {
                    return false
                }

                if let kind = input.kind,
                   symbol.kind != kind {
                    return false
                }

                return true
            }
        } else {
            candidates = []
        }

        if candidates.count == 1,
           let symbol = candidates.first {
            return symbol
        }

        let path = input.path
        let lookup = lookupDescription(
            for: input
        )

        guard !candidates.isEmpty else {
            throw ReadSwiftSymbolToolError.symbolNotFound(
                path: path,
                lookup: lookup
            )
        }

        throw ReadSwiftSymbolToolError.ambiguousSymbol(
            path: path,
            lookup: lookup,
            candidates: candidates.map(
                candidateDescription(for:)
            )
        )
    }

    func summary(
        for input: ReadSwiftSymbolTool.Input,
        renderedPath: String
    ) -> String {
        "Read Swift symbol in \(renderedPath) matching \(lookupDescription(for: input))"
    }

    func lookupDescription(
        for input: ReadSwiftSymbolTool.Input
    ) -> String {
        if let id = input.normalizedID {
            return "id '\(id)'"
        }

        var parts: [String] = []

        if let displayName = input.normalizedDisplayName {
            parts.append("displayName '\(displayName)'")
        }

        if let parentType = input.parentType,
           !parentType.isEmpty {
            parts.append("parentType '\(parentType)'")
        }

        if let kind = input.kind {
            parts.append("kind '\(kind.rawValue)'")
        }

        return parts.joined(separator: ", ")
    }

    func candidateDescription(
        for symbol: SwiftSymbolSummary
    ) -> String {
        let parent = symbol.parentType.map { "\($0)." } ?? ""
        return "\(symbol.kind.rawValue) \(parent)\(symbol.displayName) [\(symbol.lineRange.start)-\(symbol.lineRange.end)]"
    }
}

/// Read one exact Swift symbol.
/// Supply either id or displayName.
/// When using displayName, parentType and kind may further disambiguate the symbol.

private extension ReadSwiftSymbolTool.Input {
    enum CodingKeys:
        String,
        CodingKey
    {
        case path
        case id
        case displayName
        case parentType
        case kind
        case includeLineNumbers
    }
}

public extension ReadSwiftSymbolTool.Input {
    init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        self.init(
            path: try container.decode(
                String.self,
                forKey: .path
            ),
            id: try container.decodeIfPresent(
                String.self,
                forKey: .id
            ),
            displayName: try container.decodeIfPresent(
                String.self,
                forKey: .displayName
            ),
            parentType: try container.decodeIfPresent(
                String.self,
                forKey: .parentType
            ),
            kind: try container.decodeIfPresent(
                SwiftSymbolKind.self,
                forKey: .kind
            ),
            includeLineNumbers: try container.decodeIfPresent(
                Bool.self,
                forKey: .includeLineNumbers
            ) ?? true
        )
    }
}

public extension ReadSwiftSymbolTool.Input {


    var normalizedID: String? {
        normalized(id)
    }

    var normalizedDisplayName: String? {
        normalized(displayName)
    }

    var hasLookup: Bool {
        normalizedID != nil || normalizedDisplayName != nil
    }

    private func normalized(
        _ value: String?
    ) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmed.isEmpty ? nil : trimmed
    }
}
