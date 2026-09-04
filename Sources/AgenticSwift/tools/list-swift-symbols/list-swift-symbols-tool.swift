import Agentic
import AgenticExecution
import AgenticWorkspace
import Primitives
import Schema

public struct ListSwiftSymbolsTool: AgentTool {
    public typealias Input = ListSwiftSymbolsToolInput
    public typealias Output = ListSwiftSymbolsToolOutput
    public static let identifier: AgentToolIdentifier = "list_swift_symbols"
    public static let description = "List Swift symbols discovered in a Swift source file in the workspace."
    public static let risk: ActionRisk = .observe

    public let collector: SwiftSymbolCollector

    public var identifier: AgentToolIdentifier {
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
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {

        let renderedPath = try AgenticSwiftToolSupport.resolvedPreflightPath(
            input.path,
            workspace: context.workspace
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: context.workspace?.rootURL.path,
            targetPaths: [renderedPath],
            summary: summary(
                for: input,
                renderedPath: renderedPath
            )
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            context.workspace,
            toolName: name
        )
        let path = try workspace.resolve(
            input.path
        )

        var symbols = try collector.collect(
            in: path
        )

        if input.filtersByKind {
            let includedKinds = Set(
                input.includeKinds
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
                input.clampedMaxSymbols
            )
        )

        return ListSwiftSymbolsToolOutput(
                path: path.presentingRelative(
                    filetype: true
                ),
                totalSymbolCount: totalSymbolCount,
                returnedSymbolCount: returnedSymbols.count,
                truncated: returnedSymbols.count < totalSymbolCount,
                symbols: returnedSymbols
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
