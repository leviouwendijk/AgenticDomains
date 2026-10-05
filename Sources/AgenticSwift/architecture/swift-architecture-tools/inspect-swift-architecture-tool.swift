import Agentic
import Macros
import Schema
import Workspace
import Documentation

public extension SwiftLang.Tools {
    @Tool("inspect_swift_architecture")
    struct InspectArchitecture {
        @JSONSchema
        public struct Input:
            Codable,
            Sendable,
            Hashable
        {
            public let minimumAccessLevel: SwiftArchitectureAccessLevel?
            public let symbolLimit: Int?
            public let refresh: Bool?

            public init(
                minimumAccessLevel: SwiftArchitectureAccessLevel? = nil,
                symbolLimit: Int? = nil,
                refresh: Bool? = nil
            ) {
                self.minimumAccessLevel = minimumAccessLevel
                self.symbolLimit = symbolLimit
                self.refresh = refresh
            }
        }

        @JSONSchema
        public struct Output:
            Codable,
            Sendable
        {
            public let packageName: String
            public let toolsVersion: String?
            public let products: [SwiftArchitectureProduct]
            public let targets: [SwiftArchitectureTarget]
            public let modules: [String]
            public let totalSymbolCount: Int
            public let totalRelationshipCount: Int
            public let returnedSymbolCount: Int
            public let truncated: Bool
            public let symbols: [SwiftArchitectureSymbol]

            init(
                snapshot: DocumentationWorkspaceSnapshot,
                symbolLimit: Int?
            ) {
                packageName = snapshot.package.name
                toolsVersion = snapshot.package.toolsVersion
                products = snapshot.package.products.map {
                    .init(
                        name: $0.name,
                        kind: $0.kind.rawValue,
                        targets: $0.targets.map(\.rawValue)
                    )
                }
                targets = snapshot.package.targets.map {
                    .init(
                        identity: $0.identity.rawValue,
                        name: $0.name,
                        type: $0.type,
                        path: $0.path,
                        module: $0.module?.rawValue
                    )
                }
                modules = snapshot.package.modules.map(\.name)
                totalSymbolCount = snapshot.collection.symbols.count
                totalRelationshipCount = snapshot.collection.relationships.count

                let selectedSymbols: ArraySlice<DocumentationSymbol>

                if let symbolLimit {
                    selectedSymbols = snapshot.collection.symbols.prefix(
                        max(
                            1,
                            symbolLimit
                        )
                    )
                } else {
                    selectedSymbols = snapshot.collection.symbols[...]
                }

                symbols = selectedSymbols.map(
                    SwiftArchitectureSymbol.init
                )
                returnedSymbolCount = symbols.count
                truncated = returnedSymbolCount < totalSymbolCount
            }
        }

        public static let purpose =
            "Inspect compiler-derived package, module, symbol, declaration, and relationship architecture for the selected live Swift package."
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
                    "Derive compiler symbol graphs and SwiftPM topology for architecture inspection."
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

            return .init(
                snapshot: snapshot,
                symbolLimit: input.symbolLimit
            )
        }
    }
}
