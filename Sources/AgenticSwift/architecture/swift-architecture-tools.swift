import Agentic
import AgenticExecution
import Documentation

public struct InspectSwiftArchitectureTool:
    AgentTool
{
    public typealias Input = InspectSwiftArchitectureToolInput
    public typealias Output = InspectSwiftArchitectureToolOutput

    public static let identifier: AgentToolIdentifier =
        "inspect_swift_architecture"
    public static let description =
        "Inspect compiler-derived package, module, symbol, declaration, and relationship architecture for the selected live Swift package."
    public static let risk: ActionRisk =
        .privileged

    public var identifier: AgentToolIdentifier { Self.identifier }
    public var description: String { Self.description }
    public var risk: ActionRisk { Self.risk }
    public var execution: AgentToolExecutionContract { .targetable }

    public init() {}

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        _ = input

        return try SwiftArchitectureToolSupport.preflight(
            context: context,
            toolName: name,
            summary:
                "Derive compiler symbol graphs and SwiftPM topology for architecture inspection."
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let snapshot = try await SwiftArchitectureToolSupport.localSnapshot(
            context: context,
            access: input.minimumAccessLevel,
            refresh: input.refresh,
            toolName: name
        )

        return .init(
            snapshot: snapshot,
            symbolLimit: input.symbolLimit
        )
    }
}

public struct SearchSwiftArchitectureTool:
    AgentTool
{
    public typealias Input = SearchSwiftArchitectureToolInput
    public typealias Output = SearchSwiftArchitectureToolOutput

    public static let identifier: AgentToolIdentifier =
        "search_swift_architecture"
    public static let description =
        "Search compiler-derived Swift architecture symbols by semantic name, path, module, or kind."
    public static let risk: ActionRisk =
        .privileged

    public var identifier: AgentToolIdentifier { Self.identifier }
    public var description: String { Self.description }
    public var risk: ActionRisk { Self.risk }
    public var execution: AgentToolExecutionContract { .targetable }

    public init() {}

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        _ = input

        return try SwiftArchitectureToolSupport.preflight(
            context: context,
            toolName: name,
            summary:
                "Search compiler-derived Swift architecture semantics."
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let snapshot = try await SwiftArchitectureToolSupport.localSnapshot(
            context: context,
            access: input.minimumAccessLevel,
            refresh: input.refresh,
            toolName: name
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
    AgentTool
{
    public typealias Input = InspectSwiftArchitectureSymbolToolInput
    public typealias Output = InspectSwiftArchitectureSymbolToolOutput

    public static let identifier: AgentToolIdentifier =
        "inspect_swift_architecture_symbol"
    public static let description =
        "Inspect one exact compiler-derived Swift symbol with declaration references and inbound and outbound relationships."
    public static let risk: ActionRisk =
        .privileged

    public var identifier: AgentToolIdentifier { Self.identifier }
    public var description: String { Self.description }
    public var risk: ActionRisk { Self.risk }
    public var execution: AgentToolExecutionContract { .targetable }

    public init() {}

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        _ = input

        return try SwiftArchitectureToolSupport.preflight(
            context: context,
            toolName: name,
            summary:
                "Inspect one exact symbol in the compiler-derived Swift architecture graph."
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let snapshot = try await SwiftArchitectureToolSupport.localSnapshot(
            context: context,
            access: input.minimumAccessLevel,
            refresh: input.refresh,
            toolName: name
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
    AgentTool
{
    public typealias Input = InspectSwiftArchitectureRelationshipsToolInput
    public typealias Output = InspectSwiftArchitectureRelationshipsToolOutput

    public static let identifier: AgentToolIdentifier =
        "inspect_swift_architecture_relationships"
    public static let description =
        "Traverse a bounded compiler-derived semantic relationship graph from one exact Swift symbol."
    public static let risk: ActionRisk =
        .privileged

    public var identifier: AgentToolIdentifier { Self.identifier }
    public var description: String { Self.description }
    public var risk: ActionRisk { Self.risk }
    public var execution: AgentToolExecutionContract { .targetable }

    public init() {}

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        _ = input

        return try SwiftArchitectureToolSupport.preflight(
            context: context,
            toolName: name,
            summary:
                "Traverse bounded compiler-derived Swift architecture relationships."
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let snapshot = try await SwiftArchitectureToolSupport.localSnapshot(
            context: context,
            access: input.minimumAccessLevel,
            refresh: input.refresh,
            toolName: name
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
    AgentTool
{
    public typealias Input = InspectSwiftRepositoryArchitectureToolInput
    public typealias Output = InspectSwiftArchitectureToolOutput

    public static let identifier: AgentToolIdentifier =
        "inspect_swift_repository_architecture"
    public static let description =
        "Materialize an explicit Git repository revision and inspect its compiler-derived Swift architecture separately from the live workspace."
    public static let risk: ActionRisk =
        .privileged

    public var identifier: AgentToolIdentifier { Self.identifier }
    public var description: String { Self.description }
    public var risk: ActionRisk { Self.risk }
    public var execution: AgentToolExecutionContract { .targetable }

    public init() {}

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        try SwiftArchitectureToolSupport.preflight(
            context: context,
            toolName: name,
            summary:
                "Materialize \(input.origin) at the explicitly selected revision and derive compiler-backed Swift architecture semantics.",
            remote: true
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
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
