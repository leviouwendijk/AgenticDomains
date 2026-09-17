import Documentation
import Executable
import Macros
import Schema

@JSONSchema
public enum SwiftArchitectureAccessLevel:
    String,
    Codable,
    Sendable,
    Hashable,
    CaseIterable
{
    case `private`
    case `fileprivate`
    case `internal`
    case `package`
    case `public`
    case `open`

    var executable: SwiftSymbolGraphAccessLevel {
        switch self {
        case .private:
            .private
        case .fileprivate:
            .fileprivate
        case .internal:
            .internal
        case .package:
            .package
        case .public:
            .public
        case .open:
            .open
        }
    }
}

@JSONSchema
public enum SwiftArchitectureRelationshipDirection:
    String,
    Codable,
    Sendable,
    Hashable,
    CaseIterable
{
    case outbound
    case inbound
    case both
}

@JSONSchema
public enum SwiftArchitectureRepositoryRevisionKind:
    String,
    Codable,
    Sendable,
    Hashable,
    CaseIterable
{
    case branch
    case tag
    case commit
    case reference
}

@JSONSchema
public struct InspectSwiftArchitectureToolInput:
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
public struct SearchSwiftArchitectureToolInput:
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
public struct InspectSwiftArchitectureSymbolToolInput:
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
public struct InspectSwiftArchitectureRelationshipsToolInput:
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
public struct InspectSwiftRepositoryArchitectureToolInput:
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

public struct SwiftArchitectureProduct:
    Codable,
    Sendable,
    Hashable
{
    public let name: String
    public let kind: String
    public let targets: [String]
}

public struct SwiftArchitectureTarget:
    Codable,
    Sendable,
    Hashable
{
    public let identity: String
    public let name: String
    public let type: String
    public let path: String?
    public let module: String?
}

public struct SwiftArchitectureSymbol:
    Codable,
    Sendable,
    Hashable
{
    public let identity: String
    public let name: String
    public let path: [String]
    public let module: String?
    public let kind: String
    public let declaration: String?
    public let sourceURI: String?
    public let line: Int?
    public let character: Int?
    public let provenance: String

    init(
        _ symbol: DocumentationSymbol
    ) {
        identity = symbol.identity.rawValue
        name = symbol.name
        path = symbol.path
        module = symbol.module?.rawValue
        kind = symbol.kind.rawValue
        declaration = symbol.declaration?.fragments
            .map(\.spelling)
            .joined()
        sourceURI = symbol.source?.uri
        line = symbol.source?.line
        character = symbol.source?.character
        provenance = symbol.provenance.rawValue
    }
}

public struct SwiftArchitectureRelationship:
    Codable,
    Sendable,
    Hashable
{
    public let source: String
    public let target: String
    public let kind: String
    public let targetFallback: String?

    init(
        _ relationship: DocumentationRelationship
    ) {
        source = relationship.source.rawValue
        target = relationship.target.rawValue
        kind = relationship.kind.rawValue
        targetFallback = relationship.targetFallback
    }
}

public struct InspectSwiftArchitectureToolOutput:
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

public struct SearchSwiftArchitectureToolOutput:
    Codable,
    Sendable
{
    public let totalMatchCount: Int
    public let returnedCount: Int
    public let truncated: Bool
    public let symbols: [SwiftArchitectureSymbol]
}

public struct InspectSwiftArchitectureSymbolToolOutput:
    Codable,
    Sendable
{
    public let symbol: SwiftArchitectureSymbol?
    public let declarationReferences: [String]
    public let outbound: [SwiftArchitectureRelationship]
    public let inbound: [SwiftArchitectureRelationship]
}

public struct InspectSwiftArchitectureRelationshipsToolOutput:
    Codable,
    Sendable
{
    public let rootIdentity: String
    public let returnedCount: Int
    public let truncated: Bool
    public let relationships: [SwiftArchitectureRelationship]
}
