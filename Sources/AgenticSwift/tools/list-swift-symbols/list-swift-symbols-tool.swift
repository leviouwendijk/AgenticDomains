import Agentic
import Primitives

public struct ListSwiftSymbolsTool: AgentTool {
    public let definition: AgentToolDefinition
    public let collector: SwiftSymbolCollector

    public var actionRisk: ActionRisk {
        .observe
    }

    public init(
        collector: SwiftSymbolCollector = .init()
    ) {
        self.definition = .init(
            name: "list_swift_symbols",
            description: "List Swift symbols discovered in a Swift source file in the workspace."
        )
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

        return .init(
            toolName: definition.name,
            actionRisk: actionRisk,
            workspaceRoot: workspace?.rootURL.path,
            targetPaths: [decoded.path],
            summary: summary(
                for: decoded
            )
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            workspace,
            toolName: definition.name
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
        for input: ListSwiftSymbolsToolInput
    ) -> String {
        guard input.filtersByKind else {
            return "List Swift symbols in \(input.path)"
        }

        let kinds = input.includeKinds.map(\.rawValue).joined(
            separator: ", "
        )

        return "List Swift symbols in \(input.path) filtered to: \(kinds)"
    }
}
