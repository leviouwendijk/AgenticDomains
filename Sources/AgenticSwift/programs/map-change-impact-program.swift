import Agentic
import Foundation
import Macros
import Schema

public extension SwiftLang.Programs {
    /// Deterministic impact discovery: resolve a symbol from the compiler-derived
    /// architecture graph, traverse its relationships, and locate the related
    /// declarations. No model inference; every architecture call is bounded
    /// because each one is a privileged, approval-reviewed operation.
    @Program
    struct MapChangeImpact {
        @JSONSchema
        public struct Input: HashableSource {
            /// Symbol name or exact architecture identity to start from.
            public let query: String
            public let module: String?
            /// Relationship traversal depth; defaults to 1.
            public let depth: Int?
            /// How many matched symbols to treat as roots; defaults to 2.
            public let maximumRoots: Int?
            /// How many related symbols to locate; defaults to 10.
            public let maximumSites: Int?

            public init(
                query: String,
                module: String? = nil,
                depth: Int? = nil,
                maximumRoots: Int? = nil,
                maximumSites: Int? = nil
            ) {
                self.query = query
                self.module = module
                self.depth = depth
                self.maximumRoots = maximumRoots
                self.maximumSites = maximumSites
            }
        }

        @JSONSchema
        public struct ImpactSite: HashableResult {
            public let identity: String
            public let name: String
            public let kind: String
            public let module: String?
            /// `path:line`, when the graph records a source location.
            public let location: String?
            /// How this site relates to its root, e.g. `inbound conformsTo via Root`.
            public let relation: String?
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let roots: [ImpactSite]
            public let sites: [ImpactSite]
            /// Related identities found but not located within the bound.
            public let unlocated: [String]
            /// What this map does not establish; read before relying on it.
            public let coverage: [String]
        }

        public static let purpose = """
        Map the declarations related to one Swift symbol from the compiler-derived \
        architecture graph: matched roots, related symbols with source locations, \
        and explicit coverage limits. Deterministic; no model inference.
        """

        public init() {}

        public func run(
            _ input: Input,
            in context: ProgramContext
        ) async throws -> Output {
            let maximumRoots = min(max(input.maximumRoots ?? 2, 1), 5)
            let maximumSites = min(max(input.maximumSites ?? 10, 0), 30)
            let depth = min(max(input.depth ?? 1, 1), 3)

            let search = try await context.invoke(
                SwiftLang.Tools.SearchArchitecture.definition.identifier,
                input: SwiftLang.Tools.SearchArchitecture.Input(
                    query: input.query,
                    module: input.module,
                    limit: maximumRoots
                ),
                as: SwiftLang.Tools.SearchArchitecture.Output.self
            )
            let roots = search.symbols.prefix(maximumRoots).map {
                ImpactSite($0, relation: nil)
            }
            var coverage: [String] = []

            guard !roots.isEmpty else {
                return .init(
                    roots: [],
                    sites: [],
                    unlocated: [],
                    coverage: [
                        "No architecture symbol matched '\(input.query)'. Fall back to text search.",
                    ]
                )
            }
            if search.totalMatchCount > roots.count {
                coverage.append(
                    "\(search.totalMatchCount) symbols matched; only the first \(roots.count) were mapped. Narrow the query or module to choose a different root."
                )
            }

            var related: [(identity: String, relation: String)] = []
            var seen = Set(roots.map(\.identity))

            for root in roots {
                let traversal = try await context.invoke(
                    SwiftLang.Tools.InspectArchitectureRelationships.definition.identifier,
                    input: SwiftLang.Tools.InspectArchitectureRelationships.Input(
                        identity: root.identity,
                        direction: .both,
                        depth: depth
                    ),
                    as: SwiftLang.Tools.InspectArchitectureRelationships.Output.self
                )
                if traversal.truncated {
                    coverage.append(
                        "Relationships of \(root.name) were truncated at \(traversal.returnedCount)."
                    )
                }

                // Traversal returns edges breadth-first, so each new symbol is
                // reached from one already seen.
                for relationship in traversal.relationships {
                    let other: String
                    let direction: String
                    if seen.contains(relationship.target),
                       !seen.contains(relationship.source)
                    {
                        other = relationship.source
                        direction = "inbound"
                    } else if !seen.contains(relationship.target) {
                        other = relationship.target
                        direction = "outbound"
                    } else {
                        continue
                    }
                    seen.insert(other)
                    related.append(
                        (other, "\(direction) \(relationship.kind) via \(root.name)")
                    )
                }
            }

            var sites: [ImpactSite] = []
            for (identity, relation) in related.prefix(maximumSites) {
                let inspection = try await context.invoke(
                    SwiftLang.Tools.InspectArchitectureSymbol.definition.identifier,
                    input: SwiftLang.Tools.InspectArchitectureSymbol.Input(
                        identity: identity
                    ),
                    as: SwiftLang.Tools.InspectArchitectureSymbol.Output.self
                )
                if let symbol = inspection.symbol {
                    sites.append(
                        ImpactSite(symbol, relation: relation)
                    )
                }
            }
            let unlocated = related.dropFirst(maximumSites).map(\.identity)
            if !unlocated.isEmpty {
                coverage.append(
                    "\(unlocated.count) related symbols were not located; raise maximumSites or start from one of them."
                )
            }

            coverage.append(
                "The graph covers compiler-visible declarations of the current package. String-based, reflective, generated, and cross-package references are not included; text-search the root names (\(roots.map(\.name).joined(separator: ", "))) to cover them."
            )

            return .init(
                roots: Array(roots),
                sites: sites,
                unlocated: unlocated,
                coverage: coverage
            )
        }
    }
}

private extension SwiftLang.Programs.MapChangeImpact.ImpactSite {
    init(
        _ symbol: SwiftArchitectureSymbol,
        relation: String?
    ) {
        self.init(
            identity: symbol.identity,
            name: symbol.path.isEmpty
                ? symbol.name
                : symbol.path.joined(separator: "."),
            kind: symbol.kind,
            module: symbol.module,
            location: symbol.sourceURI.map { uri in
                let path = URL(string: uri)?.path ?? uri
                return symbol.line.map { "\(path):\($0)" } ?? path
            },
            relation: relation
        )
    }
}
