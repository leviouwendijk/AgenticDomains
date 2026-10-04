import Agentic
import Macros
import Schema
import Workspace
import Documentation

public extension SwiftLang.Tools {
    @Tool("inspect_swift_repository_architecture")
    struct InspectRepositoryArchitecture {
        @JSONSchema
        public struct Input:
            Codable,
            Sendable,
            Hashable
        {
            public let origin: String
            public let revisionKind: SwiftArchitectureRepositoryRevisionKind
            public let revision: String
            public let minimumAccessLevel: SwiftArchitectureAccessLevel?
            public let symbolLimit: Int?

            public init(
                origin: String,
                revisionKind: SwiftArchitectureRepositoryRevisionKind,
                revision: String,
                minimumAccessLevel: SwiftArchitectureAccessLevel? = nil,
                symbolLimit: Int? = nil
            ) {
                self.origin = origin
                self.revisionKind = revisionKind
                self.revision = revision
                self.minimumAccessLevel = minimumAccessLevel
                self.symbolLimit = symbolLimit
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
            "Materialize an explicit Git repository revision and inspect its compiler-derived Swift architecture separately from the live workspace."
        public static let risk: ActionRisk = .privileged

        public init() {}

        public func preflight(
            _ input: Input,
            workspace context: WorkspaceContext?
        ) async throws -> ToolPreflight {
            try SwiftArchitectureToolSupport.preflight(
                context: context,
                toolName: Self.definition.identifier.rawValue,
                summary:
                    "Materialize \(input.origin) at the explicitly selected revision and derive compiler-backed Swift architecture semantics.",
                remote: true
            )
        }

        public func call(
            _ input: Input,
            workspace context: WorkspaceContext?
        ) async throws -> Output {
            _ = context

            let snapshot = try await SwiftArchitectureToolSupport.remoteSnapshot(
                input: input
            )

            return .init(
                snapshot: snapshot,
                symbolLimit: input.symbolLimit
            )
        }
    }
}
