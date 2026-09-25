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
public struct SwiftArchitectureProduct:
    Codable,
    Sendable,
    Hashable
{
    public let name: String
    public let kind: String
    public let targets: [String]
}

@JSONSchema
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

@JSONSchema
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

@JSONSchema
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

