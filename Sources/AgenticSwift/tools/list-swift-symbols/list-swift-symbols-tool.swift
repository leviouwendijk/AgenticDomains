import Agentic
import Primitives

public struct ListSwiftSymbolsTool: StaticAgentTool {
    public static let identifier: AgentToolIdentifier = "list_swift_symbols"
    public static let description = "List Swift symbols discovered in a Swift source file in the workspace."
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
            ListSwiftSymbolsToolInput.self,
            from: input
        )

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
            ListSwiftSymbolsToolInput.self,
            from: input
        )
        let scopedPath = try workspace.resolve(
            decoded.path
        )

        var symbols = try collector.collect(
            in: scopedPath
        )

        if decoded.filtersByKind {
            let includedKinds = Set(
                decoded.includeKinds
            )
            symbols = symbols.filter { symbol in
                includedKinds.contains(
                    symbol.kind
                )
            }
        }

        let totalSymbolCount = symbols.count
        let returnedSymbols = Array(
            symbols.prefix(
                decoded.clampedMaxSymbols
            )
        )

        return try JSONToolBridge.encode(
            ListSwiftSymbolsToolOutput(
                path: scopedPath.presentingRelative(
                    filetype: true
                ),
                totalSymbolCount: totalSymbolCount,
                returnedSymbolCount: returnedSymbols.count,
                truncated: returnedSymbols.count < totalSymbolCount,
                symbols: returnedSymbols
            )
        )
    }
}

private extension ListSwiftSymbolsTool {
    func summary(
        for input: ListSwiftSymbolsToolInput,
        renderedPath: String
    ) -> String {
        guard input.filtersByKind else {
            return "List Swift symbols in \(renderedPath)"
        }

        let kinds = input.includeKinds.map(\.rawValue).joined(
            separator: ", "
        )

        return "List Swift symbols in \(renderedPath) filtered to: \(kinds)"
    }
}
