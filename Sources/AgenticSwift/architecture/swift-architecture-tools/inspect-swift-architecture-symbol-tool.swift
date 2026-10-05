import Agentic
import Macros
import Schema
import Workspace
import Documentation

public extension SwiftLang.Tools {
    @Tool("inspect_swift_architecture_symbol")
    struct InspectArchitectureSymbol {
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

        public static let purpose =
            "Inspect one exact compiler-derived Swift symbol with declaration references and inbound and outbound relationships."
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
                    "Inspect one exact symbol in the compiler-derived Swift architecture graph."
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
}
