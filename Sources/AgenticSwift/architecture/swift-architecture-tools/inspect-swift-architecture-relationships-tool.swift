import Agentic
import Macros
import Schema
import Workspace
import Documentation

public extension SwiftLang.Tools {
    @Tool("inspect_swift_architecture_relationships")
    struct InspectArchitectureRelationships {
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

        public static let purpose =
            "Traverse a bounded compiler-derived semantic relationship graph from one exact Swift symbol."
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
                    "Traverse bounded compiler-derived Swift architecture relationships."
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
}
