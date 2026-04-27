import Agentic
import Primitives
import Path

public struct ReadSwiftSymbolTool: StaticAgentTool {
    public static let identifier: AgentToolIdentifier = "read_swift_symbol"
    public static let description = "Read one exact Swift symbol from a Swift source file in the workspace, disambiguated by symbol id or display name."
    public static let risk: ActionRisk = .observe

    public let collector: SwiftSymbolCollector

    public init(
        collector: SwiftSymbolCollector = .init()
    ) {
        self.collector = collector
    }

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        let decoded = try JSONToolBridge.decode(
            ReadSwiftSymbolToolInput.self,
            from: input
        )

        guard decoded.hasLookup else {
            throw ReadSwiftSymbolToolError.missingLookup
        }

        let renderedPath = try AgenticSwiftToolSupport.resolvedPreflightPath(
            decoded.path,
            workspace: workspace
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: workspace?.rootURL.path,
            targetPaths: [renderedPath],
            summary: summary(
                for: decoded,
                renderedPath: renderedPath
            )
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )
        let decoded = try JSONToolBridge.decode(
            ReadSwiftSymbolToolInput.self,
            from: input
        )

        guard decoded.hasLookup else {
            throw ReadSwiftSymbolToolError.missingLookup
        }

        let scopedPath = try workspace.resolve(
            decoded.path
        )
        let symbol = try resolveSymbol(
            for: decoded,
            in: scopedPath
        )
        let read = try workspace.readSlice(
            scopedPath,
            range: symbol.lineRange
        )

        let content: String
        if let range = read.selectedLineRange {
            content = AgenticSwiftToolSupport.renderLines(
                read.selectedLines,
                startingAt: range.start,
                includeLineNumbers: decoded.includeLineNumbers
            )
        } else {
            content = ""
        }

        return try JSONToolBridge.encode(
            ReadSwiftSymbolToolOutput(
                path: scopedPath.presentingRelative(
                    filetype: true
                ),
                id: symbol.id,
                kind: symbol.kind,
                name: symbol.name,
                displayName: symbol.displayName,
                parentType: symbol.parentType,
                summary: symbol.summary,
                lineRange: symbol.lineRange,
                lineCount: read.lineCount,
                content: content
            )
        )
    }
}

private extension ReadSwiftSymbolTool {
    func resolveSymbol(
        for input: ReadSwiftSymbolToolInput,
        in scopedPath: ScopedPath
    ) throws -> SwiftSymbolSummary {
        let symbols = try collector.collect(
            in: scopedPath
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

        let path = scopedPath.presentingRelative(
            filetype: true
        )
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
        for input: ReadSwiftSymbolToolInput,
        renderedPath: String
    ) -> String {
        "Read Swift symbol in \(renderedPath) matching \(lookupDescription(for: input))"
    }

    func lookupDescription(
        for input: ReadSwiftSymbolToolInput
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
