import Agentic
import Macros
import Schema
import Workspace
import Documentation

public struct InspectSwiftArchitectureTool:
    Tool
{
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

public static let identifier: ToolIdentifier =
        "inspect_swift_architecture"
    public static let description =
        "Inspect compiler-derived package, module, symbol, declaration, and relationship architecture for the selected live Swift package."
    public static let risk: ActionRisk =
        .privileged

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier { Self.identifier }
    public var description: String { Self.description }
    public var risk: ActionRisk { Self.risk }

    public init() {}

    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        _ = input

        return try SwiftArchitectureToolSupport.preflight(
            context: context,
            toolName: Self.definition.identifier.rawValue,
            summary:
                "Derive compiler symbol graphs and SwiftPM topology for architecture inspection."
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let snapshot = try await SwiftArchitectureToolSupport.localSnapshot(
            context: context,
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

public struct SearchSwiftArchitectureTool:
    Tool
{
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

public static let identifier: ToolIdentifier =
        "search_swift_architecture"
    public static let description =
        "Search compiler-derived Swift architecture symbols by semantic name, path, module, or kind."
    public static let risk: ActionRisk =
        .privileged

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier { Self.identifier }
    public var description: String { Self.description }
    public var risk: ActionRisk { Self.risk }

    public init() {}

    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        _ = input

        return try SwiftArchitectureToolSupport.preflight(
            context: context,
            toolName: Self.definition.identifier.rawValue,
            summary:
                "Search compiler-derived Swift architecture semantics."
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let snapshot = try await SwiftArchitectureToolSupport.localSnapshot(
            context: context,
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

public struct InspectSwiftArchitectureSymbolTool:
    Tool
{
    @JSONSchema
    public struct Input:
        Codable,
        Sendable,
        Hashable
    {
        public let identity: String
        public let minimumAccessLevel: SwiftArchitectureAccessLevel?
        public let refresh: Bool?

        public init(
            identity: String,
            minimumAccessLevel: SwiftArchitectureAccessLevel? = nil,
            refresh: Bool? = nil
        ) {
            self.identity = identity
            self.minimumAccessLevel = minimumAccessLevel
            self.refresh = refresh
        }
    }

    @JSONSchema
    public struct Output:
        Codable,
        Sendable
    {
        public let symbol: SwiftArchitectureSymbol?
        public let declarationReferences: [String]
        public let outbound: [SwiftArchitectureRelationship]
        public let inbound: [SwiftArchitectureRelationship]
    }

public static let identifier: ToolIdentifier =
        "inspect_swift_architecture_symbol"
    public static let description =
        "Inspect one exact compiler-derived Swift symbol with declaration references and inbound and outbound relationships."
    public static let risk: ActionRisk =
        .privileged

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier { Self.identifier }
    public var description: String { Self.description }
    public var risk: ActionRisk { Self.risk }

    public init() {}

    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        _ = input

        return try SwiftArchitectureToolSupport.preflight(
            context: context,
            toolName: Self.definition.identifier.rawValue,
            summary:
                "Inspect one exact symbol in the compiler-derived Swift architecture graph."
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let snapshot = try await SwiftArchitectureToolSupport.localSnapshot(
            context: context,
            access: input.minimumAccessLevel,
            refresh: input.refresh,
            toolName: Self.definition.identifier.rawValue
        )
        let identity = DocumentationSymbolIdentity(
            rawValue: input.identity
        )
        let symbol = snapshot.collection.symbols.first {
            $0.identity == identity
        }
        let declarationReferences = symbol?.declaration?.fragments.compactMap {
            $0.referencedSymbol?.rawValue
        } ?? []
        let outbound = snapshot.collection.relationships
            .filter {
                $0.source == identity
            }
            .map(
                SwiftArchitectureRelationship.init
            )
        let inbound = snapshot.collection.relationships
            .filter {
                $0.target == identity
            }
            .map(
                SwiftArchitectureRelationship.init
            )

        return .init(
            symbol: symbol.map(
                SwiftArchitectureSymbol.init
            ),
            declarationReferences: declarationReferences,
            outbound: outbound,
            inbound: inbound
        )
    }
}

public struct InspectSwiftArchitectureRelationshipsTool:
    Tool
{
    @JSONSchema
    public struct Input:
        Codable,
        Sendable,
        Hashable
    {
        public let identity: String
        public let direction: SwiftArchitectureRelationshipDirection?
        public let relationshipKinds: [String]?
        public let depth: Int?
        public let limit: Int?
        public let minimumAccessLevel: SwiftArchitectureAccessLevel?
        public let refresh: Bool?

        public init(
            identity: String,
            direction: SwiftArchitectureRelationshipDirection? = nil,
            relationshipKinds: [String]? = nil,
            depth: Int? = nil,
            limit: Int? = nil,
            minimumAccessLevel: SwiftArchitectureAccessLevel? = nil,
            refresh: Bool? = nil
        ) {
            self.identity = identity
            self.direction = direction
            self.relationshipKinds = relationshipKinds
            self.depth = depth
            self.limit = limit
            self.minimumAccessLevel = minimumAccessLevel
            self.refresh = refresh
        }
    }

    @JSONSchema
    public struct Output:
        Codable,
        Sendable
    {
        public let rootIdentity: String
        public let returnedCount: Int
        public let truncated: Bool
        public let relationships: [SwiftArchitectureRelationship]
    }

public static let identifier: ToolIdentifier =
        "inspect_swift_architecture_relationships"
    public static let description =
        "Traverse a bounded compiler-derived semantic relationship graph from one exact Swift symbol."
    public static let risk: ActionRisk =
        .privileged

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier { Self.identifier }
    public var description: String { Self.description }
    public var risk: ActionRisk { Self.risk }

    public init() {}

    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        _ = input

        return try SwiftArchitectureToolSupport.preflight(
            context: context,
            toolName: Self.definition.identifier.rawValue,
            summary:
                "Traverse bounded compiler-derived Swift architecture relationships."
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let snapshot = try await SwiftArchitectureToolSupport.localSnapshot(
            context: context,
            access: input.minimumAccessLevel,
            refresh: input.refresh,
            toolName: Self.definition.identifier.rawValue
        )
        let requestedDepth = min(
            8,
            max(
                1,
                input.depth ?? 1
            )
        )
        let limit = SwiftArchitectureToolSupport.limit(
            input.limit,
            default: 500
        )
        let kinds = input.relationshipKinds.map {
            Set($0)
        }
        let direction = input.direction ?? .both
        var frontier: Set<String> = [
            input.identity,
        ]
        var visited: Set<String> = []
        var seenRelationships = Set<DocumentationRelationship>()
        var results: [DocumentationRelationship] = []

        for _ in 0..<requestedDepth {
            let current = frontier.subtracting(
                visited
            )

            if current.isEmpty {
                break
            }

            visited.formUnion(
                current
            )
            var next: Set<String> = []

            for relationship in snapshot.collection.relationships {
                if let kinds,
                   !kinds.contains(
                        relationship.kind.rawValue
                   )
                {
                    continue
                }

                let outbound = current.contains(
                    relationship.source.rawValue
                )
                let inbound = current.contains(
                    relationship.target.rawValue
                )
                let include: Bool

                switch direction {
                case .outbound:
                    include = outbound
                case .inbound:
                    include = inbound
                case .both:
                    include = outbound || inbound
                }

                guard include else {
                    continue
                }

                if seenRelationships.insert(
                    relationship
                ).inserted {
                    results.append(
                        relationship
                    )
                }

                if outbound {
                    next.insert(
                        relationship.target.rawValue
                    )
                }
                if inbound {
                    next.insert(
                        relationship.source.rawValue
                    )
                }

                if results.count >= limit {
                    return .init(
                        rootIdentity: input.identity,
                        returnedCount: results.count,
                        truncated: true,
                        relationships: results.map(
                            SwiftArchitectureRelationship.init
                        )
                    )
                }
            }

            frontier = next
        }

        return .init(
            rootIdentity: input.identity,
            returnedCount: results.count,
            truncated: false,
            relationships: results.map(
                SwiftArchitectureRelationship.init
            )
        )
    }
}

public struct InspectSwiftRepositoryArchitectureTool:
    Tool
{
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

public static let identifier: ToolIdentifier =
        "inspect_swift_repository_architecture"
    public static let description =
        "Materialize an explicit Git repository revision and inspect its compiler-derived Swift architecture separately from the live workspace."
    public static let risk: ActionRisk =
        .privileged

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier { Self.identifier }
    public var description: String { Self.description }
    public var risk: ActionRisk { Self.risk }

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
