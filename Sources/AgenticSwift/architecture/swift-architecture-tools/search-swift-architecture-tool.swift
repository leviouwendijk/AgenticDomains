import Agentic
import Macros
import Schema
import Workspace
import Documentation

public extension SwiftLang.Tools {
    @Tool("search_swift_architecture")
    struct SearchArchitecture {
        @JSONSchema
        public struct Input:
            Codable,
            Sendable,
            Hashable
        {
            public let query: String
            public let module: String?
            public let kind: String?
            public let minimumAccessLevel: SwiftArchitectureAccessLevel?
            public let limit: Int?
            public let refresh: Bool?

            public init(
                query: String,
                module: String? = nil,
                kind: String? = nil,
                minimumAccessLevel: SwiftArchitectureAccessLevel? = nil,
                limit: Int? = nil,
                refresh: Bool? = nil
            ) {
                self.query = query
                self.module = module
                self.kind = kind
                self.minimumAccessLevel = minimumAccessLevel
                self.limit = limit
                self.refresh = refresh
            }
        }

        @JSONSchema
        public struct Output:
            Codable,
            Sendable
        {
            public let totalMatchCount: Int
            public let returnedCount: Int
            public let truncated: Bool
            public let symbols: [SwiftArchitectureSymbol]
        }

        public static let purpose =
            "Search compiler-derived Swift architecture symbols by semantic name, path, module, or kind."
        public static let risk: ActionRisk = .privileged

        public init() {}

        public func preflight(
            _ input: Input,
            in context: ToolContext
        ) async throws -> ToolPreflight {
            _ = input

            return try SwiftArchitectureToolSupport.preflight(
                context: context.workspace,
                toolName: Self.definition.identifier.rawValue,
                summary:
                    "Search compiler-derived Swift architecture semantics."
            )
        }

        public func call(
            _ input: Input,
            in context: ToolContext
        ) async throws -> Output {
            let snapshot = try await SwiftArchitectureToolSupport.localSnapshot(
                context: context.workspace,
                access: input.minimumAccessLevel,
                refresh: input.refresh,
                toolName: Self.definition.identifier.rawValue
            )
            let query = input.query.lowercased()
            let matches = snapshot.collection.symbols.filter { symbol in
                let semanticName = ([symbol.name] + symbol.path)
                    .joined(
                        separator: "."
                    )
                    .lowercased()
                let queryMatches = semanticName.contains(
                    query
                )
                let moduleMatches = input.module.map {
                    symbol.module?.rawValue == $0
                } ?? true
                let kindMatches = input.kind.map {
                    symbol.kind.rawValue == $0
                } ?? true

                return queryMatches
                    && moduleMatches
                    && kindMatches
            }
            let limit = SwiftArchitectureToolSupport.limit(
                input.limit
            )
            let projected = Array(
                matches.prefix(
                    limit
                )
            ).map(
                SwiftArchitectureSymbol.init
            )

            return .init(
                totalMatchCount: matches.count,
                returnedCount: projected.count,
                truncated: projected.count < matches.count,
                symbols: projected
            )
        }
    }
}
