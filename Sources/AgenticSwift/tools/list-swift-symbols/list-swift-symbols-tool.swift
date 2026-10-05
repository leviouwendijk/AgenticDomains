import Agentic
import Macros
import Workspace
import Primitives
import Schema

public struct ListSwiftSymbolsTool: Tool {
    @JSONSchema
    public struct Input: Sendable, Codable, Hashable {
        /// Swift source file path relative to the current Agentic workspace.
        public let path: String

        /// Optional Swift symbol kinds to include. Omit or pass an empty array to include all kinds.
        @Schema(required: false)
        public let includeKinds: [SwiftSymbolKind]

        /// Optional maximum number of symbols to return. Defaults to 200 and is clamped to at least 1.
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

    @JSONSchema
    public struct Output: Sendable, Codable, Hashable {
        public let path: String
        public let totalSymbolCount: Int
        public let returnedSymbolCount: Int
        public let truncated: Bool
        public let symbols: [SwiftSymbolSummary]

        public init(
            path: String,
            totalSymbolCount: Int,
            returnedSymbolCount: Int,
            truncated: Bool,
            symbols: [SwiftSymbolSummary]
        ) {
            self.path = path
            self.totalSymbolCount = totalSymbolCount
            self.returnedSymbolCount = returnedSymbolCount
            self.truncated = truncated
            self.symbols = symbols
        }
    }

public static let identifier: ToolIdentifier = "list_swift_symbols"
    public static let description = "List Swift symbols discovered in a Swift source file in the workspace."
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
        let file = try AgenticSwiftToolSupport.projectFileURL(
            input.path,
            workspace: workspace,
            toolName: Self.definition.identifier.rawValue
        )

        var symbols = try collector.collect(
            in: file
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

        return Output(
            path: input.path,
            totalSymbolCount: totalSymbolCount,
                returnedSymbolCount: returnedSymbols.count,
                truncated: returnedSymbols.count < totalSymbolCount,
                symbols: returnedSymbols
            )
    }
}

private extension ListSwiftSymbolsTool {
    func summary(
        for input: ListSwiftSymbolsTool.Input,
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

private extension ListSwiftSymbolsTool.Input {
    enum CodingKeys:
        String,
        CodingKey
    {
        case path
        case includeKinds
        case maxSymbols
    }
}

public extension ListSwiftSymbolsTool.Input {
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
            includeKinds: try container.decodeIfPresent(
                [SwiftSymbolKind].self,
                forKey: .includeKinds
            ) ?? [],
            maxSymbols: try container.decodeIfPresent(
                Int.self,
                forKey: .maxSymbols
            )
        )
    }
}

public extension ListSwiftSymbolsTool.Input {


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
